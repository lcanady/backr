import { describe, it, expect, beforeAll, afterAll, beforeEach } from '@jest/globals';
import express from 'express';
import request from 'supertest';
import { MongoDBAdapter } from '../../db/mongodb';
import { createContractRoutes } from '../../routes/contracts';
import { createEventRoutes } from '../../routes/events';
import { createBlockRoutes } from '../../routes/blocks';

describe('API Routes', () => {
  let app: express.Application;
  let db: MongoDBAdapter;

  beforeAll(async () => {
    db = new MongoDBAdapter(process.env.MONGODB_URI!);
    await db.connect();

    app = express();
    app.use(express.json());
    app.use('/contracts', createContractRoutes(db, '../out', '../deployments'));
    app.use('/events', createEventRoutes(db));
    app.use('/blocks', createBlockRoutes(db));
  });

  afterAll(async () => {
    await db.disconnect();
  });

  beforeEach(async () => {
    const dbClient = (db as any).client.db();
    await dbClient.collection('blocks').deleteMany({});
    await dbClient.collection('contracts').deleteMany({});
    await dbClient.collection('events').deleteMany({});
  });

  describe('Contract Routes', () => {
    const mockContract = {
      address: '0x123',
      name: 'Test Contract',
      abi: '[]'
    };

    it('should add a new contract', async () => {
      const response = await request(app)
        .post('/contracts')
        .send(mockContract);

      expect(response.status).toBe(200);
      expect(response.body.message).toBe('Contract added successfully');
    });

    it('should list contracts', async () => {
      await db.addContract({
        ...mockContract,
        events: [],
        isActive: true
      });

      const response = await request(app)
        .get('/contracts');

      expect(response.status).toBe(200);
      expect(response.body.length).toBe(1);
      expect(response.body[0].address).toBe(mockContract.address);
    });
  });

  describe('Event Routes', () => {
    const mockEvent = {
      name: 'Transfer',
      signature: 'Transfer(address,address,uint256)',
      abi: 'event Transfer(address indexed from, address indexed to, uint256 value)'
    };

    beforeEach(async () => {
      await db.addContract({
        address: '0x123',
        name: 'Test Contract',
        abi: '[]',
        events: [],
        isActive: true
      });
    });

    it('should add an event to a contract', async () => {
      const response = await request(app)
        .post('/events/contracts/0x123/events')
        .send(mockEvent);

      expect(response.status).toBe(200);
      expect(response.body.message).toBe('Event added successfully');
    });

    it('should query events', async () => {
      const response = await request(app)
        .post('/events/query')
        .send({
          contractAddress: '0x123',
          fromBlock: 1,
          toBlock: 100
        });

      expect(response.status).toBe(200);
      expect(response.body).toHaveProperty('events');
      expect(response.body).toHaveProperty('total');
    });
  });

  describe('Block Routes', () => {
    const mockBlock = {
      number: 1,
      hash: '0x123',
      timestamp: 1000,
      transactions: []
    };

    beforeEach(async () => {
      await db.saveBlock(mockBlock);
    });

    it('should get block by number', async () => {
      const response = await request(app)
        .get('/blocks/1');

      expect(response.status).toBe(200);
      expect(response.body.number).toBe(1);
      expect(response.body.hash).toBe('0x123');
    });

    it('should get indexing status', async () => {
      const response = await request(app)
        .get('/blocks/status');

      expect(response.status).toBe(200);
      expect(response.body).toHaveProperty('latestIndexedBlock');
      expect(response.body).toHaveProperty('totalIndexedBlocks');
    });
  });
}); 