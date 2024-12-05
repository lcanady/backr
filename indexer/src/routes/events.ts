import { Router } from 'express';
import { randomUUID } from 'crypto';
import { DatabaseAdapter, EventConfig } from '../db/adapter';

export function createEventRoutes(db: DatabaseAdapter) {
  const router = Router();

  // Add event to contract
  router.post('/contracts/:address/events', async (req, res) => {
    const { address } = req.params;
    const { name, signature, abi } = req.body;

    if (!name || !signature || !abi) {
      return res.status(400).json({ error: 'Name, signature, and ABI are required' });
    }

    try {
      const contract = await db.getContract(address);
      if (!contract) {
        return res.status(404).json({ error: 'Contract not found' });
      }

      const newEvent: EventConfig = {
        id: randomUUID(),
        name,
        signature,
        abi,
        isActive: true
      };

      const events = [...(contract.events || []), newEvent];
      await db.updateContract(address, { events });
      res.json({ message: 'Event added successfully', eventId: newEvent.id });
    } catch (error) {
      res.status(500).json({ error: 'Failed to add event' });
    }
  });

  // Remove event from contract
  router.delete('/contracts/:address/events/:eventId', async (req, res) => {
    const { address, eventId } = req.params;

    try {
      const contract = await db.getContract(address);
      if (!contract) {
        return res.status(404).json({ error: 'Contract not found' });
      }

      const events = contract.events.map(event => 
        event.id === eventId ? { ...event, isActive: false } : event
      );

      await db.updateContract(address, { events });
      res.json({ message: 'Event removed successfully' });
    } catch (error) {
      res.status(500).json({ error: 'Failed to remove event' });
    }
  });

  // Get events for contract
  router.get('/contracts/:address/events', async (req, res) => {
    const { address } = req.params;
    const { eventName } = req.query;
    const limit = parseInt(req.query.limit as string) || 100;

    try {
      const events = await db.getEvents(address, eventName as string | undefined, limit);
      res.json(events);
    } catch (error) {
      res.status(500).json({ error: 'Failed to fetch events' });
    }
  });

  // Query events with filters
  router.post('/query', async (req, res) => {
    const {
      contractAddress,
      eventName,
      fromBlock,
      toBlock,
      fromTimestamp,
      toTimestamp,
      parameters,
      sort,
      limit,
      offset
    } = req.body;

    try {
      const query = {
        contractAddress,
        eventName,
        fromBlock,
        toBlock,
        fromTimestamp,
        toTimestamp,
        parameters,
        sort,
        limit,
        offset
      };

      const result = await db.queryEvents(query);
      res.json(result);
    } catch (error) {
      console.error('Error querying events:', error);
      res.status(500).json({ error: 'Failed to query events' });
    }
  });

  return router;
} 