const fs = require('fs');
const path = require('path');
const solc = require('solc');

const contractsDir = path.resolve(__dirname, 'contracts');
const artifactsDir = path.resolve(__dirname, 'artifacts');

// Create artifacts folder if not exists
if (!fs.existsSync(artifactsDir)) {
  fs.mkdirSync(artifactsDir);
}

// Load all `.sol` files
const files = fs.readdirSync(contractsDir).filter(file => file.endsWith('.sol'));

if (files.length === 0) {
  console.error("❌ No .sol files found in the contracts folder.");
  process.exit(1);
}

for (const fileName of files) {
  const filePath = path.join(contractsDir, fileName);
  const source = fs.readFileSync(filePath, 'utf8');

  const input = {
    language: 'Solidity',
    sources: {
      [fileName]: {
        content: source,
      },
    },
    settings: {
      outputSelection: {
        '*': {
          '*': ['*'],
        },
      },
    },
  };

  try {
    const output = JSON.parse(solc.compile(JSON.stringify(input)));

    if (output.errors) {
      for (const err of output.errors) {
        console.log(`${err.severity === 'error' ? '❌' : '⚠️'} ${err.formattedMessage}`);
      }
    }

    for (const contractName in output.contracts[fileName]) {
      const contract = output.contracts[fileName][contractName];
      const abiPath = path.join(artifactsDir, `${contractName}.abi.json`);
      const bytecodePath = path.join(artifactsDir, `${contractName}.bin.txt`);

      fs.writeFileSync(abiPath, JSON.stringify(contract.abi, null, 2));
      fs.writeFileSync(bytecodePath, contract.evm.bytecode.object);

      console.log(`\n✅ Compiled: ${contractName}`);
      console.log(`📦 ABI saved to: ${abiPath}`);
      console.log(`🔗 Bytecode saved to: ${bytecodePath}`);
    }
  } catch (err) {
    console.error(`❌ Compilation failed for ${fileName}:`, err.message);
  }
}
