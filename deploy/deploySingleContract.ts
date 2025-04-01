import { ContractType, ContractInfo, deployLensContract } from './lensUtils';

async function deploy() {
  //////////////// SETUP /////////////////
  const contractToDeploy: ContractInfo =
    {
      name: 'LensFactoryImpl',
      contractName: 'LensFactory',
      contractType: ContractType.Implementation,
      constructorArguments: [
        {
          accessControlFactory: '0x5eb740362F17815Ae67EBcA6420Cbb350f714C3E',
          accountFactory: '0xE55C2154d1766a9C6319dBD989C89867b0457358',
          appFactory: '0xc650f3CcfF7801F5e95a99B99AAbD2f6319d38ed',
          groupFactory: '0xEF51808f8a2399282CDd156E897473b282998a29',
          feedFactory: '0xb8169FB0FaB6a699854fd4fD2457b990988E1372',
          graphFactory: '0x7cbB07bD2E80A27c59Ed707B79024cC5e54dEaF0',
          namespaceFactory: '0xb69CBb69041a30216e2fe13E9700b32761b859C3'
        },
        {
          accountBlockingRule:'0xf3de16e99679243E36BB449CADEA247Cf61450e1',
          groupGatedFeedRule: '0xbDE71d01eC6d6c49b2bcc9067EcA352a17D25A91',
          usernameSimpleCharsetRule: '0x1dB51f49DE4D266B2ab7D62656510083e0AACe44',
          banMemberGroupRule: '0xd12E1aD028d550F85F2a8d9130C46dB77A6A0a41',
          addRemovePidGroupRule: '0x90d39577A9a6C76ED8a5b2B908a7053ef5430194',
          usernameReservedNamespaceRule: '0x9a8b0e3344f5ca5f6fc9FcEb8fF543FDeF5eb2b9'
        }
      ],
    };
  ////////////////////////////////////////

  const deployedImplementation = await deployLensContract(
    contractToDeploy,
    true
  );

  console.log(
    `${contractToDeploy.contractName} deployed at ${deployedImplementation.address}`
  );
  console.table(deployedImplementation);
}

if (require.main === module) {
  deploy()
    .then(() => process.exit(0))
    .catch((error) => {
      console.error(error);
      process.exit(1);
    });
}

export default deploy;
