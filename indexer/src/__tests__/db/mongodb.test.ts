import { MongoDBAdapter } from '../../db/mongodb';
import { BlockData, ContractConfig, EventData } from '../../db/adapter';
import { describe, it, expect, beforeAll, afterAll, beforeEach } from '@jest/globals';

describe('MongoDBAdapter', () => {
  let adapter: MongoDBAdapter;

  beforeAll(async () => {
    adapter = new MongoDBAdapter(process.env.MONGODB_URI!);
    await adapter.connect();
  });

  afterAll(async () => {
    await adapter.disconnect();
  });

  beforeEach(async () => {
    // Clear collections before each test
    const db = (adapter as any).client.db();
    await db.collection('blocks').deleteMany({});
    await db.collection('contracts').deleteMany({});
    await db.collection('events').deleteMany({});
  });

  describe('Blocks', () => {
    const mockBlock: BlockData = {
      number: 1,
      hash: '0x123',
      timestamp: 1000,
      transactions: ['0xabc']
    };

    it('should save and retrieve a block', async () => {
      await adapter.saveBlock(mockBlock);
      const retrieved = await adapter.getBlock(mockBlock.number);
      expect(retrieved).toEqual(mockBlock);
    });

    it('should get latest block', async () => {
      await adapter.saveBlock({ ...mockBlock, number: 1 });
      await adapter.saveBlock({ ...mockBlock, number: 2 });
      const latest = await adapter.getLatestBlock();
      expect(latest?.number).toBe(2);
    });
  });

  describe('Contracts', () => {
    const mockContract: ContractConfig = {
      address: '0x123',
      name: 'Test Contract',
      abi: '[]',
      events: [],
      isActive: true,
      createdAt: new Date(),
      updatedAt: new Date()
    };

    it('should add and retrieve a contract', async () => {
      await adapter.addContract(mockContract);
      const retrieved = await adapter.getContract(mockContract.address);
      expect(retrieved?.address).toBe(mockContract.address);
    });

    it('should list active contracts', async () => {
      await adapter.addContract(mockContract);
      await adapter.addContract({ ...mockContract, address: '0x456', isActive: false });
      const activeContracts = await adapter.listContracts(true);
      expect(activeContracts.length).toBe(1);
      expect(activeContracts[0].address).toBe('0x123');
    });
  });

  describe('Events', () => {
    const mockEvent: EventData = {
      id: '1',
      contractAddress: '0x123',
      eventName: 'Transfer',
      blockNumber: 1,
      transactionHash: '0xabc',
      timestamp: 1000,
      returnValues: { from: '0x123', to: '0x456', value: '1000' },
      raw: { data: '0x', topics: [] }
    };

    it('should save and retrieve events', async () => {
      await adapter.saveEvent(mockEvent);
      const events = await adapter.getEvents(mockEvent.contractAddress);
      expect(events.length).toBe(1);
      expect(events[0].id).toBe(mockEvent.id);
    });

    it('should query events with filters', async () => {
      await adapter.saveEvent(mockEvent);
      await adapter.saveEvent({ ...mockEvent, id: '2', blockNumber: 2 });

      const result = await adapter.queryEvents({
        contractAddress: '0x123',
        fromBlock: 1,
        toBlock: 1
      });

      expect(result.events.length).toBe(1);
      expect(result.total).toBe(1);
    });
  });
}); 