import express from 'express';
import { providers, Contract, utils } from 'ethers';
import type { Block, Log } from '@ethersproject/abstract-provider';
import dotenv from 'dotenv';
import { DatabaseAdapter, EventConfig, EventData } from './db/adapter';
import { MongoDBAdapter } from './db/mongodb';
import { loadContractsFromSource } from './contracts';
import { createContractRoutes } from './routes/contracts';
import { createEventRoutes } from './routes/events';
import { createBlockRoutes } from './routes/blocks';

dotenv.config();

const app = express();
app.use(express.json());

const port = process.env.PORT || 3000;
const ETHEREUM_RPC_URL = process.env.ETHEREUM_RPC_URL || 'https://eth-mainnet.g.alchemy.com/v2/your-api-key';
const MONGODB_URI = process.env.MONGODB_URI || 'mongodb://localhost:27017/backr';
const ABI_PATH = process.env.ABI_PATH || '../out';
const DEPLOYMENTS_PATH = process.env.DEPLOYMENTS_PATH || '../deployments';

// Initialize provider and database
const provider = new providers.JsonRpcProvider(ETHEREUM_RPC_URL);
const db: DatabaseAdapter = new MongoDBAdapter(MONGODB_URI);

let isIndexing = false;
let latestIndexedBlock = 0;

// Process events from a block for a contract
async function processContractEvents(
  contract: Contract,
  eventConfigs: EventConfig[],
  block: Block,
  logs: Log[]
): Promise<void> {
  const contractAddress = contract.target.toString().toLowerCase();
  const timestamp = Number(block.timestamp);

  for (const log of logs) {
    try {
      const parsedLog = contract.interface.parseLog({
        topics: log.topics,
        data: log.data
      });
      if (!parsedLog) continue;

      const eventConfig = eventConfigs.find(e => e.isActive && parsedLog.name === e.name);
      if (!eventConfig) continue;

      const event: EventData = {
        id: `${log.transactionHash}-${log.logIndex}`,
        contractAddress,
        eventName: parsedLog.name,
        blockNumber: log.blockNumber,
        transactionHash: log.transactionHash,
        timestamp,
        returnValues: parsedLog.args.toObject(),
        raw: {
          data: log.data,
          topics: log.topics
        }
      };

      await db.saveEvent(event);
      console.log(`Indexed event ${event.eventName} from tx ${event.transactionHash}`);
    } catch (error) {
      console.error(`Error processing event:`, error);
    }
  }
}

// Add this function to find missing block ranges
async function findMissingBlockRanges(fromBlock: number, toBlock: number): Promise<Array<{start: number; end: number}>> {
  const ranges: Array<{start: number; end: number}> = [];
  let currentStart = fromBlock;
  
  for (let blockNum = fromBlock; blockNum <= toBlock; blockNum++) {
    const block = await db.getBlock(blockNum);
    
    if (!block) {
      // If this is the start of a new gap
      if (currentStart !== blockNum) {
        currentStart = blockNum;
      }
    } else if (currentStart < blockNum) {
      // We found a block after a gap, record the range
      ranges.push({ start: currentStart, end: blockNum - 1 });
      currentStart = blockNum + 1;
    } else {
      currentStart = blockNum + 1;
    }
  }
  
  // Check if we ended with a gap
  if (currentStart <= toBlock) {
    ranges.push({ start: currentStart, end: toBlock });
  }
  
  return ranges;
}

// Index historical blocks
async function indexBlocks(fromBlock: number, toBlock: number) {
  try {
    isIndexing = true;
    
    // Get active contracts
    const activeContracts = await db.listContracts(true);
    const contractsWithEvents = activeContracts.filter(c => c.events?.some(e => e.isActive));
    
    for (let blockNumber = fromBlock; blockNumber <= toBlock; blockNumber++) {
      const block = await provider.getBlock(blockNumber);
      
      if (block) {
        // Save block data
        await db.saveBlock({
          number: block.number,
          hash: block.hash,
          timestamp: Number(block.timestamp),
          transactions: []
        });

        // Process events for each contract
        for (const contractConfig of contractsWithEvents) {
          if (!contractConfig.abi) continue;

          const contract = new Contract(
            contractConfig.address,
            contractConfig.abi,
            provider
          );

          const logs = await provider.getLogs({
            address: contractConfig.address,
            fromBlock: block.number,
            toBlock: block.number
          });
          
          await processContractEvents(contract, contractConfig.events, block, logs);
        }
        
        latestIndexedBlock = blockNumber;
        console.log(`Indexed block ${blockNumber}`);
      }
    }
  } catch (error) {
    console.error('Error indexing blocks:', error);
  } finally {
    isIndexing = false;
  }
}

// Initialize and setup routes
async function initialize() {
  try {
    await db.connect();
    console.log('Connected to database');
    
    // Setup routes
    app.use('/contracts', createContractRoutes(db, ABI_PATH, DEPLOYMENTS_PATH));
    app.use('/events', createEventRoutes(db));
    app.use('/blocks', createBlockRoutes(db));
    
    // Load contracts from source files
    await loadContractsFromSource(db, ABI_PATH, DEPLOYMENTS_PATH);
    console.log('Loaded contracts from source');

    // Get the latest indexed block and current chain head
    const latestIndexed = await db.getLatestBlock();
    const currentBlock = await provider.getBlockNumber();
    
    // Check for missing blocks
    if (latestIndexed) {
      const startBlock = Math.max(0, latestIndexed.number - 1000);
      console.log(`Checking for missing blocks between ${startBlock} and ${currentBlock}`);
      
      const missingRanges = await findMissingBlockRanges(startBlock, currentBlock);
      
      if (missingRanges.length > 0) {
        console.log('Found missing block ranges:', missingRanges);
        
        const chunkSize = 100;
        for (const range of missingRanges) {
          for (let start = range.start; start <= range.end; start += chunkSize) {
            const end = Math.min(start + chunkSize - 1, range.end);
            console.log(`Indexing missing blocks ${start} to ${end}`);
            await indexBlocks(start, end);
          }
        }
      }
    } else {
      const startBlock = Math.max(0, currentBlock - 1000);
      console.log(`No blocks indexed. Starting from block ${startBlock}`);
      await indexBlocks(startBlock, currentBlock);
    }
    
    // Start listening to new blocks
    provider.on('block', async (blockNumber: number) => {
      try {
        const existingBlock = await db.getBlock(blockNumber);
        if (existingBlock) {
          console.log(`Block ${blockNumber} already indexed, skipping`);
          return;
        }

        const block = await provider.getBlock(blockNumber);
        if (!block) return;

        await db.saveBlock({
          number: block.number,
          hash: block.hash,
          timestamp: Number(block.timestamp),
          transactions: []
        });

        const activeContracts = await db.listContracts(true);
        const contractsWithEvents = activeContracts.filter(c => c.events?.some(e => e.isActive));

        for (const contractConfig of contractsWithEvents) {
          if (!contractConfig.abi) continue;

          const contract = new Contract(
            contractConfig.address,
            contractConfig.abi,
            provider
          );

          const logs = await provider.getLogs({
            address: contractConfig.address,
            fromBlock: block.number,
            toBlock: block.number
          });
          
          await processContractEvents(contract, contractConfig.events, block, logs);
        }

        latestIndexedBlock = blockNumber;
        console.log(`Indexed block ${blockNumber}`);
      } catch (error) {
        console.error(`Error processing block ${blockNumber}:`, error);
      }
    });
    
    console.log('Started block listener');
  } catch (error) {
    console.error('Initialization error:', error);
    process.exit(1);
  }
}

// Graceful shutdown
process.on('SIGTERM', async () => {
  await db.disconnect();
  process.exit(0);
});

// Initialize and start the server
initialize().then(() => {
  app.listen(port, () => {
    console.log(`Indexer API running on port ${port}`);
  });
}); 