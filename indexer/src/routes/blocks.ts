import { Router } from 'express';
import { DatabaseAdapter } from '../db/adapter';

export function createBlockRoutes(db: DatabaseAdapter) {
  const router = Router();

  // Get block by number
  router.get('/:number', async (req, res) => {
    const blockNumber = parseInt(req.params.number);
    const block = await db.getBlock(blockNumber);
    
    if (!block) {
      return res.status(404).json({ error: 'Block not found' });
    }
    
    res.json(block);
  });

  // Get indexing status
  router.get('/status', async (req, res) => {
    const totalBlocks = await db.getTotalBlocks();
    const latestBlock = await db.getLatestBlock();
    const activeContracts = await db.listContracts(true);

    res.json({
      latestIndexedBlock: latestBlock?.number || 0,
      totalIndexedBlocks: totalBlocks,
      activeContracts: activeContracts.map(c => ({
        address: c.address,
        name: c.name,
        events: c.events?.filter(e => e.isActive).map(e => e.name)
      }))
    });
  });

  return router;
} 