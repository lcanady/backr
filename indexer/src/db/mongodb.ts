import { MongoClient, Collection, Filter, Document } from 'mongodb';
import { BlockData, ContractTransaction, ContractConfig, DatabaseAdapter, EventData, EventQuery } from './adapter';

export class MongoDBAdapter implements DatabaseAdapter {
  private client: MongoClient;
  private blocksCollection: Collection<BlockData> | null = null;
  private txCollection: Collection<ContractTransaction> | null = null;
  private contractsCollection: Collection<ContractConfig> | null = null;
  private eventsCollection: Collection<EventData> | null = null;

  constructor(uri: string) {
    this.client = new MongoClient(uri);
  }

  async connect(): Promise<void> {
    await this.client.connect();
    const db = this.client.db('evm_indexer');
    this.blocksCollection = db.collection<BlockData>('blocks');
    this.txCollection = db.collection<ContractTransaction>('transactions');
    this.contractsCollection = db.collection<ContractConfig>('contracts');
    this.eventsCollection = db.collection<EventData>('events');
    
    // Create indexes
    await this.blocksCollection.createIndex({ number: 1 }, { unique: true });
    await this.txCollection.createIndex({ hash: 1 }, { unique: true });
    await this.txCollection.createIndex({ to: 1 });
    await this.txCollection.createIndex({ blockNumber: -1 });
    await this.contractsCollection.createIndex({ address: 1 }, { unique: true });
    await this.eventsCollection.createIndex({ id: 1 }, { unique: true });
    await this.eventsCollection.createIndex({ contractAddress: 1, eventName: 1 });
    await this.eventsCollection.createIndex({ blockNumber: 1 });
  }

  async disconnect(): Promise<void> {
    await this.client.close();
  }

  async saveBlock(block: BlockData): Promise<void> {
    if (!this.blocksCollection) throw new Error('Database not connected');
    await this.blocksCollection.updateOne(
      { number: block.number },
      { $set: block },
      { upsert: true }
    );
  }

  async getBlock(blockNumber: number): Promise<BlockData | null> {
    if (!this.blocksCollection) throw new Error('Database not connected');
    return await this.blocksCollection.findOne<BlockData>(
      { number: blockNumber },
      { projection: { _id: 0 } }
    );
  }

  async getLatestBlock(): Promise<BlockData | null> {
    if (!this.blocksCollection) throw new Error('Database not connected');
    return await this.blocksCollection.findOne<BlockData>(
      {},
      { sort: { number: -1 }, projection: { _id: 0 } }
    );
  }

  async getTotalBlocks(): Promise<number> {
    if (!this.blocksCollection) throw new Error('Database not connected');
    return await this.blocksCollection.countDocuments();
  }

  async saveContractTransaction(tx: ContractTransaction): Promise<void> {
    if (!this.txCollection) throw new Error('Database not connected');
    await this.txCollection.updateOne(
      { hash: tx.hash },
      { $set: tx },
      { upsert: true }
    );
  }

  async getContractTransactions(contractAddress: string, limit: number = 100): Promise<ContractTransaction[]> {
    if (!this.txCollection) throw new Error('Database not connected');
    return await this.txCollection
      .find<ContractTransaction>(
        { to: contractAddress.toLowerCase() },
        { projection: { _id: 0 } }
      )
      .sort({ blockNumber: -1 })
      .limit(limit)
      .toArray();
  }

  async addContract(config: Omit<ContractConfig, 'createdAt' | 'updatedAt'>): Promise<void> {
    if (!this.contractsCollection) throw new Error('Database not connected');
    const now = new Date();
    await this.contractsCollection.updateOne(
      { address: config.address.toLowerCase() },
      {
        $set: {
          ...config,
          address: config.address.toLowerCase(),
          events: config.events || [],
          createdAt: now,
          updatedAt: now
        }
      },
      { upsert: true }
    );
  }

  async removeContract(address: string): Promise<void> {
    if (!this.contractsCollection) throw new Error('Database not connected');
    await this.contractsCollection.updateOne(
      { address: address.toLowerCase() },
      { $set: { isActive: false, updatedAt: new Date() } }
    );
  }

  async getContract(address: string): Promise<ContractConfig | null> {
    if (!this.contractsCollection) throw new Error('Database not connected');
    return await this.contractsCollection.findOne<ContractConfig>(
      { address: address.toLowerCase() },
      { projection: { _id: 0 } }
    );
  }

  async listContracts(activeOnly: boolean = true): Promise<ContractConfig[]> {
    if (!this.contractsCollection) throw new Error('Database not connected');
    const query = activeOnly ? { isActive: true } : {};
    return await this.contractsCollection
      .find<ContractConfig>(query, { projection: { _id: 0 } })
      .sort({ createdAt: -1 })
      .toArray();
  }

  async updateContract(address: string, updates: Partial<ContractConfig>): Promise<void> {
    if (!this.contractsCollection) throw new Error('Database not connected');
    const { address: _, createdAt, updatedAt, ...validUpdates } = updates;
    await this.contractsCollection.updateOne(
      { address: address.toLowerCase() },
      {
        $set: {
          ...validUpdates,
          updatedAt: new Date()
        }
      }
    );
  }

  async saveEvent(event: EventData): Promise<void> {
    if (!this.eventsCollection) throw new Error('Database not connected');
    await this.eventsCollection.updateOne(
      { id: event.id },
      { $set: event },
      { upsert: true }
    );
  }

  async getEvents(
    contractAddress: string,
    eventName?: string,
    limit: number = 100
  ): Promise<EventData[]> {
    if (!this.eventsCollection) throw new Error('Database not connected');
    const query: Filter<EventData> = { contractAddress: contractAddress.toLowerCase() };
    if (eventName) {
      query.eventName = eventName;
    }
    
    return await this.eventsCollection
      .find<EventData>(query, { projection: { _id: 0 } })
      .sort({ blockNumber: -1, id: 1 })
      .limit(limit)
      .toArray();
  }

  async getEventsByBlockRange(
    fromBlock: number,
    toBlock: number
  ): Promise<EventData[]> {
    if (!this.eventsCollection) throw new Error('Database not connected');
    return await this.eventsCollection
      .find<EventData>(
        {
          blockNumber: {
            $gte: fromBlock,
            $lte: toBlock
          }
        },
        { projection: { _id: 0 } }
      )
      .sort({ blockNumber: 1, id: 1 })
      .toArray();
  }

  async queryEvents(query: EventQuery): Promise<{ events: EventData[]; total: number }> {
    if (!this.eventsCollection) throw new Error('Database not connected');

    const filter: Filter<EventData> = {};

    if (query.contractAddress) {
      filter.contractAddress = query.contractAddress.toLowerCase();
    }

    if (query.eventName) {
      filter.eventName = query.eventName;
    }

    if (query.fromBlock || query.toBlock) {
      filter.blockNumber = {};
      if (query.fromBlock) {
        filter.blockNumber.$gte = query.fromBlock;
      }
      if (query.toBlock) {
        filter.blockNumber.$lte = query.toBlock;
      }
    }

    if (query.fromTimestamp || query.toTimestamp) {
      filter.timestamp = {};
      if (query.fromTimestamp) {
        filter.timestamp.$gte = query.fromTimestamp;
      }
      if (query.toTimestamp) {
        filter.timestamp.$lte = query.toTimestamp;
      }
    }

    if (query.parameters) {
      for (const [key, value] of Object.entries(query.parameters)) {
        filter[`returnValues.${key}`] = value;
      }
    }

    const sort: { [key: string]: 1 | -1 } = {};
    if (query.sort) {
      for (const [key, direction] of Object.entries(query.sort)) {
        sort[key] = direction === 'asc' ? 1 : -1;
      }
    } else {
      sort.blockNumber = -1;
    }

    const limit = query.limit || 100;
    const offset = query.offset || 0;

    const [events, total] = await Promise.all([
      this.eventsCollection
        .find<EventData>(filter, { projection: { _id: 0 } })
        .sort(sort)
        .skip(offset)
        .limit(limit)
        .toArray(),
      this.eventsCollection.countDocuments(filter)
    ]);

    return { events, total };
  }
} 