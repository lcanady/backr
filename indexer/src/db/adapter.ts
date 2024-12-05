export interface BlockData {
  number: number;
  hash: string;
  timestamp: number;
  transactions: string[];
}

export interface ContractTransaction {
  hash: string;
  blockNumber: number;
  from: string;
  to: string;
  value: string;
  data: string;
  timestamp: number;
}

export interface EventConfig {
  id: string;
  name: string;
  signature: string;
  abi: string;
  isActive: boolean;
}

export interface EventData {
  id: string;
  contractAddress: string;
  eventName: string;
  blockNumber: number;
  transactionHash: string;
  timestamp: number;
  returnValues: Record<string, any>;
  raw?: {
    data: string;
    topics: string[];
  };
}

export interface EventQuery {
  contractAddress?: string;
  eventName?: string;
  fromBlock?: number;
  toBlock?: number;
  fromTimestamp?: number;
  toTimestamp?: number;
  parameters?: {
    [key: string]: any;
  };
  sort?: {
    [key: string]: 'asc' | 'desc';
  };
  limit?: number;
  offset?: number;
}

export interface ContractConfig {
  address: string;
  name?: string;
  startBlock?: number;
  abi?: string;
  events: EventConfig[];
  isActive: boolean;
  createdAt: Date;
  updatedAt: Date;
}

export interface DatabaseAdapter {
  connect(): Promise<void>;
  disconnect(): Promise<void>;
  saveBlock(block: BlockData): Promise<void>;
  getBlock(blockNumber: number): Promise<BlockData | null>;
  getLatestBlock(): Promise<BlockData | null>;
  getTotalBlocks(): Promise<number>;
  saveContractTransaction(tx: ContractTransaction): Promise<void>;
  getContractTransactions(contractAddress: string, limit?: number): Promise<ContractTransaction[]>;
  
  // Contract configuration methods
  addContract(config: Omit<ContractConfig, 'createdAt' | 'updatedAt'>): Promise<void>;
  removeContract(address: string): Promise<void>;
  getContract(address: string): Promise<ContractConfig | null>;
  listContracts(activeOnly?: boolean): Promise<ContractConfig[]>;
  updateContract(address: string, updates: Partial<ContractConfig>): Promise<void>;

  // Event methods
  saveEvent(event: EventData): Promise<void>;
  getEvents(contractAddress: string, eventName?: string, limit?: number): Promise<EventData[]>;
  getEventsByBlockRange(fromBlock: number, toBlock: number): Promise<EventData[]>;
  queryEvents(query: EventQuery): Promise<{ events: EventData[]; total: number; }>;
} 