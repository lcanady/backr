import { readFileSync, readdirSync } from 'fs';
import { join, extname } from 'path';
import { utils } from 'ethers';
import { ContractConfig, EventConfig } from './db/adapter';

interface ContractSource {
  name: string;
  address: string;
  abi: any[];
}

interface ForgeArtifact {
  abi: any[];
  bytecode: string;
  deployedBytecode: string;
}

interface DeploymentInfo {
  address: string;
  network: string;
}

export function scanContractFiles(
  abiPath: string = '../out',
  deploymentsPath: string = '../deployments'
): ContractSource[] {
  const contracts: ContractSource[] = [];
  const deployments = new Map<string, DeploymentInfo>();

  // First, load deployments
  try {
    const deploymentFiles = readdirSync(deploymentsPath);
    for (const file of deploymentFiles) {
      if (extname(file) !== '.json') continue;
      
      try {
        const fullPath = join(deploymentsPath, file);
        const content = readFileSync(fullPath, 'utf-8');
        const deploymentData = JSON.parse(content);
        
        // Store deployment info by contract name
        const contractName = file.replace('.json', '');
        deployments.set(contractName, deploymentData);
      } catch (error) {
        console.error(`Error processing deployment file ${file}:`, error);
      }
    }
  } catch (error) {
    console.error('Error reading deployments directory:', error);
  }

  // Then load ABIs from Forge artifacts
  try {
    const files = readdirSync(abiPath, { recursive: true }) as string[];
    
    for (const file of files) {
      if (!file.endsWith('.json')) continue;
      
      try {
        const fullPath = join(abiPath, file);
        const content = readFileSync(fullPath, 'utf-8');
        const artifactData = JSON.parse(content) as ForgeArtifact;
        
        if (!artifactData.abi) continue;
        
        // Extract contract name from file path
        const contractName = file.split('/').pop()?.replace('.json', '');
        if (!contractName) continue;
        
        // Look for deployment info
        const deployment = deployments.get(contractName);
        if (!deployment?.address) {
          console.log(`No deployment found for contract ${contractName}`);
          continue;
        }

        contracts.push({
          name: contractName,
          address: deployment.address,
          abi: artifactData.abi
        });
        
        console.log(`Found contract ${contractName} at ${deployment.address}`);
      } catch (error) {
        console.error(`Error processing artifact file ${file}:`, error);
      }
    }
  } catch (error) {
    console.error(`Error reading ABI directory:`, error);
  }

  return contracts;
}

export function parseContractEvents(contractSource: ContractSource): EventConfig[] {
  try {
    const iface = new utils.Interface(contractSource.abi);
    const fragments = Object.values(iface.fragments);
    const events = fragments.filter((f): f is utils.EventFragment => 
      f.type === 'event'
    );

    return events.map(event => ({
      id: `${contractSource.address}-${event.name}`,
      name: event.name,
      signature: event.format('sighash'),
      abi: event.format('json'),
      isActive: true
    }));
  } catch (error) {
    console.error(`Error parsing events for contract ${contractSource.name}:`, error);
    return [];
  }
}

export function createContractConfig(contractSource: ContractSource): Omit<ContractConfig, 'createdAt' | 'updatedAt'> {
  const events = parseContractEvents(contractSource);
  
  return {
    address: contractSource.address,
    name: contractSource.name,
    abi: JSON.stringify(contractSource.abi),
    events,
    isActive: true
  };
}

export async function loadContractsFromSource(
  db: any,
  abiPath: string = '../out',
  deploymentsPath: string = '../deployments'
): Promise<void> {
  const contracts = scanContractFiles(abiPath, deploymentsPath);
  
  for (const contract of contracts) {
    try {
      const config = createContractConfig(contract);
      await db.addContract(config);
      console.log(`Loaded contract ${contract.name} at ${contract.address}`);
    } catch (error) {
      console.error(`Error loading contract ${contract.name}:`, error);
    }
  }
} 