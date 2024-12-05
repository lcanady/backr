import { MongoMemoryServer } from 'mongodb-memory-server';
import { MongoClient } from 'mongodb';
import '@jest/globals';

let mongoServer: MongoMemoryServer;
let mongoClient: MongoClient;

beforeAll(async () => {
  mongoServer = await MongoMemoryServer.create();
  const mongoUri = mongoServer.getUri();
  mongoClient = new MongoClient(mongoUri);
  await mongoClient.connect();
  
  // Set environment variables for testing
  process.env.MONGODB_URI = mongoUri;
  process.env.ETHEREUM_RPC_URL = 'http://localhost:8545'; // For local testing
});

afterAll(async () => {
  if (mongoClient) {
    await mongoClient.close();
  }
  if (mongoServer) {
    await mongoServer.stop();
  }
}); 