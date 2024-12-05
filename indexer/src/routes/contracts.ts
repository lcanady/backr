import { Router } from 'express';
import { utils } from 'ethers';
import { randomUUID } from 'crypto';
import { DatabaseAdapter } from '../db/adapter';
import { loadContractsFromSource } from '../contracts';

export function createContractRoutes(db: DatabaseAdapter, abiPath: string, deploymentsPath: string) {
  const router = Router();

  // List contracts and status
  router.get('/', async (req, res) => {
    const activeOnly = req.query.activeOnly !== 'false';
    const contracts = await db.listContracts(activeOnly);
    res.json(contracts);
  });

  // Add new contract
  router.post('/', async (req, res) => {
    const { address, name, startBlock, abi, events } = req.body;
    
    if (!address) {
      return res.status(400).json({ error: 'Address is required' });
    }
    
    try {
      // Validate ABI if provided
      if (abi) {
        new utils.Interface(abi);
      }

      // Process events if provided
      const processedEvents = events?.map((event: any) => ({
        id: randomUUID(),
        name: event.name,
        signature: event.signature,
        abi: event.abi,
        isActive: true
      })) || [];

      await db.addContract({
        address,
        name,
        startBlock,
        abi,
        events: processedEvents,
        isActive: true
      });
      res.json({ message: 'Contract added successfully' });
    } catch (error) {
      res.status(500).json({ error: 'Failed to add contract' });
    }
  });

  // Remove contract
  router.delete('/:address', async (req, res) => {
    const { address } = req.params;
    
    try {
      await db.removeContract(address);
      res.json({ message: 'Contract removed successfully' });
    } catch (error) {
      res.status(500).json({ error: 'Failed to remove contract' });
    }
  });

  // Get contract transactions
  router.get('/:address/transactions', async (req, res) => {
    const { address } = req.params;
    const limit = parseInt(req.query.limit as string) || 100;
    
    const contract = await db.getContract(address);
    if (!contract || !contract.isActive) {
      return res.status(404).json({ error: 'Contract not found or inactive' });
    }
    
    const transactions = await db.getContractTransactions(address, limit);
    res.json(transactions);
  });

  // Reload contracts from source
  router.post('/reload', async (req, res) => {
    try {
      await loadContractsFromSource(db, abiPath, deploymentsPath);
      res.json({ message: 'Contracts reloaded successfully' });
    } catch (error) {
      console.error('Error reloading contracts:', error);
      res.status(500).json({ error: 'Failed to reload contracts' });
    }
  });

  return router;
} 