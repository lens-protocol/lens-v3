Ran 2 tests for test/migration/Events.t.sol:EventsTest
[PASS] testBaseDeployments() (gas: 209)
Traces:
  [69075621] EventsTest::setUp()
    ├─ [300390] → new Lock@0x5615dEB798BB3E4dFa0139dFa1b3D433Cc23b72f
    │   ├─ emit OwnershipTransferred(previousOwner: 0x0000000000000000000000000000000000000000, newOwner: LOCK_OWNER: [0x2C20E2de579295747Ff21320bf3d0B7FAd355287])
    │   ├─ emit LockStatusSet(locked: true)
    │   └─ ← [Return] 1261 bytes of code
    ├─ [1308625] → new RoleBasedAccessControl@0x2e234DAe75C793f67A35089C9d99245E1C58470b
    │   ├─ emit Lens_Contract_Deployed(indexedContractType: 0x64617ee3c6a0361a9a8223334a8f2dacd3fe2087125e4536dd1d8f73178934e8, indexedFlavour: 0x093c630990be0ef4f9d7e6cb1063e8f803f969923c42de86f87415cd0478f3e4, contractType: "access-control", flavour: "lens.access-control.role-based-access-control")
    │   ├─ emit Lens_AccessControl_RoleGranted(account: EventsTest: [0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496], roleId: 30805062194276299293655310260615960901372458835523149434691481342518336257662 [3.08e76])
    │   ├─ emit Lens_AccessControl_AccessAdded(roleId: 30805062194276299293655310260615960901372458835523149434691481342518336257662 [3.08e76], contractAddress: 0x0000000000000000000000000000000000000000, permissionId: 0, granted: true)
    │   └─ ← [Return] 6044 bytes of code
    ├─ [317606] → new LensUsernameTokenURIProvider@0xF62849F9A0B5Bf2913b396098F7c7019b51A820a
    │   ├─ emit Lens_Contract_Deployed(indexedContractType: 0xbf1e12f844536c694f637eeb1c5d30750741a46be650ade6f09f76cda08be40e, indexedFlavour: 0x3a9f616ebfff760f8cf8a4d5dc8d661ade11caae0a74ddf2d6abc50e6948343c, contractType: "username-token-uri-provider", flavour: "lens.username.token-uri-provider")
    │   └─ ← [Return] 1566 bytes of code
    ├─ [4114803] → new App@0x5991A2dF15A8F6A256D3Ec51E99254Cd3fb576A9
    │   └─ ← [Return] 20439 bytes of code
    ├─ [3293602] → new Account@0xc7183455a4C133Ae270771860664b6B7ec320bB1
    │   ├─ emit OwnershipTransferred(previousOwner: 0x0000000000000000000000000000000000000000, newOwner: EventsTest: [0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496])
    │   ├─ emit Lens_Account_OwnerTransferred(newOwner: EventsTest: [0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496])
    │   └─ ← [Return] 16213 bytes of code
    ├─ [7975378] → new Feed@0xa0Cb889707d426A7A386870A03bc70d1b0697598
    │   └─ ← [Return] 39713 bytes of code
    ├─ [6424867] → new Graph@0x1d1499e622D69689cdf9004d05Ec547d650Ff211
    │   └─ ← [Return] 31973 bytes of code
    ├─ [5323821] → new Group@0xA4AD4f68d0b91CFD19687c881e50f3A00242828c
    │   └─ ← [Return] 26476 bytes of code
    ├─ [8118418] → new Namespace@0x03A6a84cD762D9707A21605b548aaaB891562aAb
    │   └─ ← [Return] 40427 bytes of code
    ├─ [491679] → new Beacon@0xD6BbDE9174b1CdAa358d2Cf4D57D1a9F7178FBfF
    │   ├─ emit OwnershipTransferred(previousOwner: 0x0000000000000000000000000000000000000000, newOwner: LOCK_OWNER: [0x2C20E2de579295747Ff21320bf3d0B7FAd355287])
    │   ├─ emit ImplementationSetForVersion(version: 1, implementation: App: [0x5991A2dF15A8F6A256D3Ec51E99254Cd3fb576A9])
    │   ├─ emit DefaultVersionSet(version: 1)
    │   └─ ← [Return] 2097 bytes of code
    ├─ [491679] → new Beacon@0x15cF58144EF33af1e14b5208015d11F9143E27b9
    │   ├─ emit OwnershipTransferred(previousOwner: 0x0000000000000000000000000000000000000000, newOwner: LOCK_OWNER: [0x2C20E2de579295747Ff21320bf3d0B7FAd355287])
    │   ├─ emit ImplementationSetForVersion(version: 1, implementation: Account: [0xc7183455a4C133Ae270771860664b6B7ec320bB1])
    │   ├─ emit DefaultVersionSet(version: 1)
    │   └─ ← [Return] 2097 bytes of code
    ├─ [491679] → new Beacon@0x212224D2F2d262cd093eE13240ca4873fcCBbA3C
    │   ├─ emit OwnershipTransferred(previousOwner: 0x0000000000000000000000000000000000000000, newOwner: LOCK_OWNER: [0x2C20E2de579295747Ff21320bf3d0B7FAd355287])
    │   ├─ emit ImplementationSetForVersion(version: 1, implementation: Feed: [0xa0Cb889707d426A7A386870A03bc70d1b0697598])
    │   ├─ emit DefaultVersionSet(version: 1)
    │   └─ ← [Return] 2097 bytes of code
    ├─ [491679] → new Beacon@0x2a07706473244BC757E10F2a9E86fB532828afe3
    │   ├─ emit OwnershipTransferred(previousOwner: 0x0000000000000000000000000000000000000000, newOwner: LOCK_OWNER: [0x2C20E2de579295747Ff21320bf3d0B7FAd355287])
    │   ├─ emit ImplementationSetForVersion(version: 1, implementation: Graph: [0x1d1499e622D69689cdf9004d05Ec547d650Ff211])
    │   ├─ emit DefaultVersionSet(version: 1)
    │   └─ ← [Return] 2097 bytes of code
    ├─ [491679] → new Beacon@0x3D7Ebc40AF7092E3F1C81F2e996cbA5Cae2090d7
    │   ├─ emit OwnershipTransferred(previousOwner: 0x0000000000000000000000000000000000000000, newOwner: LOCK_OWNER: [0x2C20E2de579295747Ff21320bf3d0B7FAd355287])
    │   ├─ emit ImplementationSetForVersion(version: 1, implementation: Group: [0xA4AD4f68d0b91CFD19687c881e50f3A00242828c])
    │   ├─ emit DefaultVersionSet(version: 1)
    │   └─ ← [Return] 2097 bytes of code
    ├─ [491679] → new Beacon@0xD16d567549A2a2a2005aEACf7fB193851603dd70
    │   ├─ emit OwnershipTransferred(previousOwner: 0x0000000000000000000000000000000000000000, newOwner: LOCK_OWNER: [0x2C20E2de579295747Ff21320bf3d0B7FAd355287])
    │   ├─ emit ImplementationSetForVersion(version: 1, implementation: Namespace: [0x03A6a84cD762D9707A21605b548aaaB891562aAb])
    │   ├─ emit DefaultVersionSet(version: 1)
    │   └─ ← [Return] 2097 bytes of code
    ├─ [2435279] → new AppFactory@0x96d3F6c20EEd2697647F543fE6C08bC2Fbf39758
    │   └─ ← [Return] 12160 bytes of code
    ├─ [2478331] → new AccountFactory@0x13aa49bAc059d709dd0a18D6bb63290076a702D7
    │   └─ ← [Return] 12375 bytes of code
    ├─ [2817781] → new FeedFactory@0xDB25A7b768311dE128BBDa7B8426c3f9C74f3240
    │   ├─ [139781] → new PermissionlessAccessControl@0xA02A0858A7B38B1f7F3230FAD136BD895C412CE5
    │   │   └─ ← [Return] 698 bytes of code
    │   └─ ← [Return] 13211 bytes of code
    ├─ [826837] → new TransparentUpgradeableProxy@0x3381cD18e2Fb4dB236BF0525938AB6E43Db0440f
    │   ├─ emit Upgraded(implementation: FeedFactory: [0xDB25A7b768311dE128BBDa7B8426c3f9C74f3240])
    │   ├─ emit AdminChanged(previousAdmin: 0x0000000000000000000000000000000000000000, newAdmin: Lock: [0x5615dEB798BB3E4dFa0139dFa1b3D433Cc23b72f])
    │   └─ ← [Return] 3884 bytes of code
    ├─ [2817781] → new GraphFactory@0x756e0562323ADcDA4430d6cb456d9151f605290B
    │   ├─ [139781] → new PermissionlessAccessControl@0x514dd0Bcaf5994Ef889f482B79d39D18B6E4363F
    │   │   └─ ← [Return] 698 bytes of code
    │   └─ ← [Return] 13211 bytes of code
    ├─ [3017219] → new GroupFactory@0x1aF7f588A501EA2B5bB3feeFA744892aA2CF00e6
    │   ├─ [139781] → new PermissionlessAccessControl@0x1f8FC9dBEbe2d5471b686313fd2546f2d3D4f9Cc
    │   │   └─ ← [Return] 698 bytes of code
    │   └─ ← [Return] 14207 bytes of code
    ├─ [2890872] → new NamespaceFactory@0xe8dc788818033232EF9772CB2e6622F1Ec8bc840
    │   ├─ [139781] → new PermissionlessAccessControl@0xFb02F4fa07b34d7a3587051169EE9E18D237263C
    │   │   └─ ← [Return] 698 bytes of code
    │   └─ ← [Return] 13576 bytes of code
    ├─ [1550895] → new AccountBlockingRule@0x3Cff5E7eBecb676c3Cb602D0ef2d46710b88854E
    │   ├─ emit OwnershipTransferred(previousOwner: 0x0000000000000000000000000000000000000000, newOwner: EventsTest: [0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496])
    │   ├─ emit Lens_Rule_MetadataURISet(metadataURI: "uri://any")
    │   └─ ← [Return] 7497 bytes of code
    ├─ [1181701] → new GroupGatedFeedRule@0x27cc01A4676C73fe8b6d0933Ac991BfF1D77C4da
    │   ├─ emit OwnershipTransferred(previousOwner: 0x0000000000000000000000000000000000000000, newOwner: EventsTest: [0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496])
    │   ├─ emit Lens_Rule_MetadataURISet(metadataURI: "uri://any")
    │   └─ ← [Return] 5653 bytes of code
    ├─ [1034748] → new UsernameSimpleCharsetNamespaceRule@0x796f2974e3C1af763252512dd6d521E9E984726C
    │   ├─ emit OwnershipTransferred(previousOwner: 0x0000000000000000000000000000000000000000, newOwner: EventsTest: [0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496])
    │   ├─ emit Lens_Rule_MetadataURISet(metadataURI: "uri://any")
    │   └─ ← [Return] 4919 bytes of code
    ├─ [1881781] → new AccessControlFactory@0x92a6649Fdcc044DA968d94202465578a9371C7b1
    │   └─ ← [Return] 9399 bytes of code
    ├─ [4530509] → new LensFactory@0xDA5A5ADC64C8013d334A0DA9e711B364Af7A4C2d
    │   ├─ [139781] → new PermissionlessAccessControl@0xF69b9ed619386c9C7FFe4240B34B9F707E21EB34
    │   │   └─ ← [Return] 698 bytes of code
    │   └─ ← [Return] 21751 bytes of code
    └─ ← [Stop]

  [209] EventsTest::testBaseDeployments()
    └─ ← [Stop]

[PASS] testEvents() (gas: 16276231)
Traces:
  [69075621] EventsTest::setUp()
    ├─ [300390] → new Lock@0x5615dEB798BB3E4dFa0139dFa1b3D433Cc23b72f
    │   ├─ emit OwnershipTransferred(previousOwner: 0x0000000000000000000000000000000000000000, newOwner: LOCK_OWNER: [0x2C20E2de579295747Ff21320bf3d0B7FAd355287])
    │   ├─ emit LockStatusSet(locked: true)
    │   └─ ← [Return] 1261 bytes of code
    ├─ [1308625] → new RoleBasedAccessControl@0x2e234DAe75C793f67A35089C9d99245E1C58470b
    │   ├─ emit Lens_Contract_Deployed(indexedContractType: 0x64617ee3c6a0361a9a8223334a8f2dacd3fe2087125e4536dd1d8f73178934e8, indexedFlavour: 0x093c630990be0ef4f9d7e6cb1063e8f803f969923c42de86f87415cd0478f3e4, contractType: "access-control", flavour: "lens.access-control.role-based-access-control")
    │   ├─ emit Lens_AccessControl_RoleGranted(account: EventsTest: [0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496], roleId: 30805062194276299293655310260615960901372458835523149434691481342518336257662 [3.08e76])
    │   ├─ emit Lens_AccessControl_AccessAdded(roleId: 30805062194276299293655310260615960901372458835523149434691481342518336257662 [3.08e76], contractAddress: 0x0000000000000000000000000000000000000000, permissionId: 0, granted: true)
    │   └─ ← [Return] 6044 bytes of code
    ├─ [317606] → new LensUsernameTokenURIProvider@0xF62849F9A0B5Bf2913b396098F7c7019b51A820a
    │   ├─ emit Lens_Contract_Deployed(indexedContractType: 0xbf1e12f844536c694f637eeb1c5d30750741a46be650ade6f09f76cda08be40e, indexedFlavour: 0x3a9f616ebfff760f8cf8a4d5dc8d661ade11caae0a74ddf2d6abc50e6948343c, contractType: "username-token-uri-provider", flavour: "lens.username.token-uri-provider")
    │   └─ ← [Return] 1566 bytes of code
    ├─ [4114803] → new App@0x5991A2dF15A8F6A256D3Ec51E99254Cd3fb576A9
    │   └─ ← [Return] 20439 bytes of code
    ├─ [3293602] → new Account@0xc7183455a4C133Ae270771860664b6B7ec320bB1
    │   ├─ emit OwnershipTransferred(previousOwner: 0x0000000000000000000000000000000000000000, newOwner: EventsTest: [0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496])
    │   ├─ emit Lens_Account_OwnerTransferred(newOwner: EventsTest: [0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496])
    │   └─ ← [Return] 16213 bytes of code
    ├─ [7975378] → new Feed@0xa0Cb889707d426A7A386870A03bc70d1b0697598
    │   └─ ← [Return] 39713 bytes of code
    ├─ [6424867] → new Graph@0x1d1499e622D69689cdf9004d05Ec547d650Ff211
    │   └─ ← [Return] 31973 bytes of code
    ├─ [5323821] → new Group@0xA4AD4f68d0b91CFD19687c881e50f3A00242828c
    │   └─ ← [Return] 26476 bytes of code
    ├─ [8118418] → new Namespace@0x03A6a84cD762D9707A21605b548aaaB891562aAb
    │   └─ ← [Return] 40427 bytes of code
    ├─ [491679] → new Beacon@0xD6BbDE9174b1CdAa358d2Cf4D57D1a9F7178FBfF
    │   ├─ emit OwnershipTransferred(previousOwner: 0x0000000000000000000000000000000000000000, newOwner: LOCK_OWNER: [0x2C20E2de579295747Ff21320bf3d0B7FAd355287])
    │   ├─ emit ImplementationSetForVersion(version: 1, implementation: App: [0x5991A2dF15A8F6A256D3Ec51E99254Cd3fb576A9])
    │   ├─ emit DefaultVersionSet(version: 1)
    │   └─ ← [Return] 2097 bytes of code
    ├─ [491679] → new Beacon@0x15cF58144EF33af1e14b5208015d11F9143E27b9
    │   ├─ emit OwnershipTransferred(previousOwner: 0x0000000000000000000000000000000000000000, newOwner: LOCK_OWNER: [0x2C20E2de579295747Ff21320bf3d0B7FAd355287])
    │   ├─ emit ImplementationSetForVersion(version: 1, implementation: Account: [0xc7183455a4C133Ae270771860664b6B7ec320bB1])
    │   ├─ emit DefaultVersionSet(version: 1)
    │   └─ ← [Return] 2097 bytes of code
    ├─ [491679] → new Beacon@0x212224D2F2d262cd093eE13240ca4873fcCBbA3C
    │   ├─ emit OwnershipTransferred(previousOwner: 0x0000000000000000000000000000000000000000, newOwner: LOCK_OWNER: [0x2C20E2de579295747Ff21320bf3d0B7FAd355287])
    │   ├─ emit ImplementationSetForVersion(version: 1, implementation: Feed: [0xa0Cb889707d426A7A386870A03bc70d1b0697598])
    │   ├─ emit DefaultVersionSet(version: 1)
    │   └─ ← [Return] 2097 bytes of code
    ├─ [491679] → new Beacon@0x2a07706473244BC757E10F2a9E86fB532828afe3
    │   ├─ emit OwnershipTransferred(previousOwner: 0x0000000000000000000000000000000000000000, newOwner: LOCK_OWNER: [0x2C20E2de579295747Ff21320bf3d0B7FAd355287])
    │   ├─ emit ImplementationSetForVersion(version: 1, implementation: Graph: [0x1d1499e622D69689cdf9004d05Ec547d650Ff211])
    │   ├─ emit DefaultVersionSet(version: 1)
    │   └─ ← [Return] 2097 bytes of code
    ├─ [491679] → new Beacon@0x3D7Ebc40AF7092E3F1C81F2e996cbA5Cae2090d7
    │   ├─ emit OwnershipTransferred(previousOwner: 0x0000000000000000000000000000000000000000, newOwner: LOCK_OWNER: [0x2C20E2de579295747Ff21320bf3d0B7FAd355287])
    │   ├─ emit ImplementationSetForVersion(version: 1, implementation: Group: [0xA4AD4f68d0b91CFD19687c881e50f3A00242828c])
    │   ├─ emit DefaultVersionSet(version: 1)
    │   └─ ← [Return] 2097 bytes of code
    ├─ [491679] → new Beacon@0xD16d567549A2a2a2005aEACf7fB193851603dd70
    │   ├─ emit OwnershipTransferred(previousOwner: 0x0000000000000000000000000000000000000000, newOwner: LOCK_OWNER: [0x2C20E2de579295747Ff21320bf3d0B7FAd355287])
    │   ├─ emit ImplementationSetForVersion(version: 1, implementation: Namespace: [0x03A6a84cD762D9707A21605b548aaaB891562aAb])
    │   ├─ emit DefaultVersionSet(version: 1)
    │   └─ ← [Return] 2097 bytes of code
    ├─ [2435279] → new AppFactory@0x96d3F6c20EEd2697647F543fE6C08bC2Fbf39758
    │   └─ ← [Return] 12160 bytes of code
    ├─ [2478331] → new AccountFactory@0x13aa49bAc059d709dd0a18D6bb63290076a702D7
    │   └─ ← [Return] 12375 bytes of code
    ├─ [2817781] → new FeedFactory@0xDB25A7b768311dE128BBDa7B8426c3f9C74f3240
    │   ├─ [139781] → new PermissionlessAccessControl@0xA02A0858A7B38B1f7F3230FAD136BD895C412CE5
    │   │   └─ ← [Return] 698 bytes of code
    │   └─ ← [Return] 13211 bytes of code
    ├─ [826837] → new TransparentUpgradeableProxy@0x3381cD18e2Fb4dB236BF0525938AB6E43Db0440f
    │   ├─ emit Upgraded(implementation: FeedFactory: [0xDB25A7b768311dE128BBDa7B8426c3f9C74f3240])
    │   ├─ emit AdminChanged(previousAdmin: 0x0000000000000000000000000000000000000000, newAdmin: Lock: [0x5615dEB798BB3E4dFa0139dFa1b3D433Cc23b72f])
    │   └─ ← [Return] 3884 bytes of code
    ├─ [2817781] → new GraphFactory@0x756e0562323ADcDA4430d6cb456d9151f605290B
    │   ├─ [139781] → new PermissionlessAccessControl@0x514dd0Bcaf5994Ef889f482B79d39D18B6E4363F
    │   │   └─ ← [Return] 698 bytes of code
    │   └─ ← [Return] 13211 bytes of code
    ├─ [3017219] → new GroupFactory@0x1aF7f588A501EA2B5bB3feeFA744892aA2CF00e6
    │   ├─ [139781] → new PermissionlessAccessControl@0x1f8FC9dBEbe2d5471b686313fd2546f2d3D4f9Cc
    │   │   └─ ← [Return] 698 bytes of code
    │   └─ ← [Return] 14207 bytes of code
    ├─ [2890872] → new NamespaceFactory@0xe8dc788818033232EF9772CB2e6622F1Ec8bc840
    │   ├─ [139781] → new PermissionlessAccessControl@0xFb02F4fa07b34d7a3587051169EE9E18D237263C
    │   │   └─ ← [Return] 698 bytes of code
    │   └─ ← [Return] 13576 bytes of code
    ├─ [1550895] → new AccountBlockingRule@0x3Cff5E7eBecb676c3Cb602D0ef2d46710b88854E
    │   ├─ emit OwnershipTransferred(previousOwner: 0x0000000000000000000000000000000000000000, newOwner: EventsTest: [0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496])
    │   ├─ emit Lens_Rule_MetadataURISet(metadataURI: "uri://any")
    │   └─ ← [Return] 7497 bytes of code
    ├─ [1181701] → new GroupGatedFeedRule@0x27cc01A4676C73fe8b6d0933Ac991BfF1D77C4da
    │   ├─ emit OwnershipTransferred(previousOwner: 0x0000000000000000000000000000000000000000, newOwner: EventsTest: [0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496])
    │   ├─ emit Lens_Rule_MetadataURISet(metadataURI: "uri://any")
    │   └─ ← [Return] 5653 bytes of code
    ├─ [1034748] → new UsernameSimpleCharsetNamespaceRule@0x796f2974e3C1af763252512dd6d521E9E984726C
    │   ├─ emit OwnershipTransferred(previousOwner: 0x0000000000000000000000000000000000000000, newOwner: EventsTest: [0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496])
    │   ├─ emit Lens_Rule_MetadataURISet(metadataURI: "uri://any")
    │   └─ ← [Return] 4919 bytes of code
    ├─ [1881781] → new AccessControlFactory@0x92a6649Fdcc044DA968d94202465578a9371C7b1
    │   └─ ← [Return] 9399 bytes of code
    ├─ [4530509] → new LensFactory@0xDA5A5ADC64C8013d334A0DA9e711B364Af7A4C2d
    │   ├─ [139781] → new PermissionlessAccessControl@0xF69b9ed619386c9C7FFe4240B34B9F707E21EB34
    │   │   └─ ← [Return] 698 bytes of code
    │   └─ ← [Return] 21751 bytes of code
    └─ ← [Stop]

  [16534931] EventsTest::testEvents()
    ├─ [3348650] LensFactory::deployFeed("uri://any", EventsTest: [0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496], [], [], [])
    │   ├─ [1409272] AccessControlFactory::deployOwnerAdminOnlyAccessControl(EventsTest: [0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496], [])
    │   │   ├─ [1319029] → new OwnerAdminOnlyAccessControl@0x1ad9e72CD508c47cDd24165E79F93D0d97dB888d
    │   │   │   ├─ emit Lens_Contract_Deployed(indexedContractType: 0x64617ee3c6a0361a9a8223334a8f2dacd3fe2087125e4536dd1d8f73178934e8, indexedFlavour: 0x8a77be47894bc95246876669e852d75c5320ba0a5ff56a0429873be5430d1f44, contractType: "access-control", flavour: "lens.access-control.owner-admin-only-access-control")
    │   │   │   ├─ emit Lens_AccessControl_RoleGranted(account: AccessControlFactory: [0x92a6649Fdcc044DA968d94202465578a9371C7b1], roleId: 30805062194276299293655310260615960901372458835523149434691481342518336257662 [3.08e76])
    │   │   │   ├─ emit Lens_AccessControl_AccessAdded(roleId: 30805062194276299293655310260615960901372458835523149434691481342518336257662 [3.08e76], contractAddress: 0x0000000000000000000000000000000000000000, permissionId: 0, granted: true)
    │   │   │   ├─ emit Lens_AccessControl_AccessAdded(roleId: 114319738593337656181689926536180396990758527023329145853867225489060618038901 [1.143e77], contractAddress: 0x0000000000000000000000000000000000000000, permissionId: 0, granted: true)
    │   │   │   └─ ← [Return] 5969 bytes of code
    │   │   ├─ emit Lens_AccessControlFactory_OwnerAdminDeployment(accessControl: OwnerAdminOnlyAccessControl: [0x1ad9e72CD508c47cDd24165E79F93D0d97dB888d], owner: EventsTest: [0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496])
    │   │   ├─ [52481] OwnerAdminOnlyAccessControl::transferOwnership(EventsTest: [0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496])
    │   │   │   ├─ emit Lens_AccessControl_RoleRevoked(account: AccessControlFactory: [0x92a6649Fdcc044DA968d94202465578a9371C7b1], roleId: 30805062194276299293655310260615960901372458835523149434691481342518336257662 [3.08e76])
    │   │   │   ├─ emit Lens_AccessControl_RoleGranted(account: EventsTest: [0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496], roleId: 30805062194276299293655310260615960901372458835523149434691481342518336257662 [3.08e76])
    │   │   │   ├─ emit Lens_OwnershipTransferred(previousOwner: AccessControlFactory: [0x92a6649Fdcc044DA968d94202465578a9371C7b1], newOwner: EventsTest: [0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496])
    │   │   │   └─ ← [Stop]
    │   │   └─ ← [Return] OwnerAdminOnlyAccessControl: [0x1ad9e72CD508c47cDd24165E79F93D0d97dB888d]
    │   ├─ [1925520] TransparentUpgradeableProxy::fallback("uri://any", OwnerAdminOnlyAccessControl: [0x1ad9e72CD508c47cDd24165E79F93D0d97dB888d], EventsTest: [0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496], [RuleChange({ ruleAddress: 0x3Cff5E7eBecb676c3Cb602D0ef2d46710b88854E, configSalt: 0x0000000000000000000000000000000000000000000000000000000000000000, configurationChanges: RuleConfigurationChange({ configure: true, ruleParams: [] }), selectorChanges: [RuleSelectorChange({ ruleSelector: 0xf8748c20, isRequired: true, enabled: true })] })], [])
    │   │   ├─ [1918119] FeedFactory::deployFeed("uri://any", OwnerAdminOnlyAccessControl: [0x1ad9e72CD508c47cDd24165E79F93D0d97dB888d], EventsTest: [0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496], [RuleChange({ ruleAddress: 0x3Cff5E7eBecb676c3Cb602D0ef2d46710b88854E, configSalt: 0x0000000000000000000000000000000000000000000000000000000000000000, configurationChanges: RuleConfigurationChange({ configure: true, ruleParams: [] }), selectorChanges: [RuleSelectorChange({ ruleSelector: 0xf8748c20, isRequired: true, enabled: true })] })], []) [delegatecall]
    │   │   │   ├─ [673168] → new ProxyAdmin@0x269C4753e15E47d7CaD8B230ed19cFff21f29D51
    │   │   │   │   ├─ emit OwnershipTransferred(previousOwner: 0x0000000000000000000000000000000000000000, newOwner: EventsTest: [0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496])
    │   │   │   │   ├─ [2472] Lock::isLocked() [staticcall]
    │   │   │   │   │   └─ ← [Return] true
    │   │   │   │   └─ ← [Return] 3212 bytes of code
    │   │   │   ├─ [878165] → new BeaconProxy@0x84331fdf4F2974B3Cb6D8003584CE74f62599F38
    │   │   │   │   ├─ emit AdminChanged(previousAdmin: 0x0000000000000000000000000000000000000000, newAdmin: ProxyAdmin: [0x269C4753e15E47d7CaD8B230ed19cFff21f29D51])
    │   │   │   │   ├─ emit AutoUpgradeChanged(enabled: true)
    │   │   │   │   ├─ emit BeaconUpgraded(beacon: Beacon: [0x212224D2F2d262cd093eE13240ca4873fcCBbA3C])
    │   │   │   │   ├─ [4668] Beacon::implementation() [staticcall]
    │   │   │   │   │   └─ ← [Return] Feed: [0xa0Cb889707d426A7A386870A03bc70d1b0697598]
    │   │   │   │   ├─ emit Upgraded(implementation: Feed: [0xa0Cb889707d426A7A386870A03bc70d1b0697598])
    │   │   │   │   └─ ← [Return] 3873 bytes of code
    │   │   │   ├─ [95526] BeaconProxy::fallback("uri://any", PermissionlessAccessControl: [0xA02A0858A7B38B1f7F3230FAD136BD895C412CE5])
    │   │   │   │   ├─ [668] Beacon::implementation() [staticcall]
    │   │   │   │   │   └─ ← [Return] Feed: [0xa0Cb889707d426A7A386870A03bc70d1b0697598]
    │   │   │   │   ├─ [90779] Feed::initialize("uri://any", PermissionlessAccessControl: [0xA02A0858A7B38B1f7F3230FAD136BD895C412CE5]) [delegatecall]
    │   │   │   │   │   ├─ emit Lens_Feed_MetadataURISet(metadataURI: "uri://any")
    │   │   │   │   │   ├─ emit Lens_PermissionId_Available(permissionId: 38466158132835170259124534014582147097694553473091316621073709598217750698359 [3.846e76], name: "lens.permission.ChangeRules")
    │   │   │   │   │   ├─ emit Lens_PermissionId_Available(permissionId: 103155344723252794140333994655397123942861665251273923900803877733460157067242 [1.031e77], name: "lens.permission.SetMetadata")
    │   │   │   │   │   ├─ emit Lens_PermissionId_Available(permissionId: 70240964901469819303340425463478853942631622821288580975892518941391166957354 [7.024e76], name: "lens.permission.SetExtraData")
    │   │   │   │   │   ├─ emit Lens_PermissionId_Available(permissionId: 17061423789868115606116092629947832508085478617756540659475605735037375356041 [1.706e76], name: "lens.permission.RemovePost")
    │   │   │   │   │   ├─ emit Lens_Contract_Deployed(indexedContractType: 0x4258863e2d81c316e4a4dd381c3c50f57f933be22afba98b4485a605da0f7811, indexedFlavour: 0x51c2b4a7d1e3a68b17d4fe52715980fde2f04336467bfde2999877bbf168d4a2, contractType: "feed", flavour: "lens.feed")
    │   │   │   │   │   ├─ [1032] PermissionlessAccessControl::hasAccess(BeaconProxy: [0x84331fdf4F2974B3Cb6D8003584CE74f62599F38], BeaconProxy: [0x84331fdf4F2974B3Cb6D8003584CE74f62599F38], 1) [staticcall]
    │   │   │   │   │   │   └─ ← [Return] true
    │   │   │   │   │   ├─ [315] PermissionlessAccessControl::getType() [staticcall]
    │   │   │   │   │   │   └─ ← [Return] 0xb5440aae9cc7331e30d1f5f4d93e4b545e210d2a6887783d935991d99a3c4dae
    │   │   │   │   │   ├─ emit Lens_AccessControlAdded(accessControl: PermissionlessAccessControl: [0xA02A0858A7B38B1f7F3230FAD136BD895C412CE5], accessControlType: 0xb5440aae9cc7331e30d1f5f4d93e4b545e210d2a6887783d935991d99a3c4dae)
    │   │   │   │   │   └─ ← [Stop]
    │   │   │   │   └─ ← [Return]
    │   │   │   ├─ [175816] BeaconProxy::fallback([RuleChange({ ruleAddress: 0x3Cff5E7eBecb676c3Cb602D0ef2d46710b88854E, configSalt: 0x0000000000000000000000000000000000000000000000000000000000000000, configurationChanges: RuleConfigurationChange({ configure: true, ruleParams: [] }), selectorChanges: [RuleSelectorChange({ ruleSelector: 0xf8748c20, isRequired: true, enabled: true })] })])
    │   │   │   │   ├─ [668] Beacon::implementation() [staticcall]
    │   │   │   │   │   └─ ← [Return] Feed: [0xa0Cb889707d426A7A386870A03bc70d1b0697598]
    │   │   │   │   ├─ [173509] Feed::changeFeedRules([RuleChange({ ruleAddress: 0x3Cff5E7eBecb676c3Cb602D0ef2d46710b88854E, configSalt: 0x0000000000000000000000000000000000000000000000000000000000000000, configurationChanges: RuleConfigurationChange({ configure: true, ruleParams: [] }), selectorChanges: [RuleSelectorChange({ ruleSelector: 0xf8748c20, isRequired: true, enabled: true })] })]) [delegatecall]
    │   │   │   │   │   ├─ [1032] PermissionlessAccessControl::hasAccess(TransparentUpgradeableProxy: [0x3381cD18e2Fb4dB236BF0525938AB6E43Db0440f], BeaconProxy: [0x84331fdf4F2974B3Cb6D8003584CE74f62599F38], 38466158132835170259124534014582147097694553473091316621073709598217750698359 [3.846e76]) [staticcall]
    │   │   │   │   │   │   └─ ← [Return] true
    │   │   │   │   │   ├─ [724] AccountBlockingRule::configure(0x0000000000000000000000000000000000000000000000000000000000000001, [])
    │   │   │   │   │   │   └─ ← [Stop]
    │   │   │   │   │   ├─ emit Lens_Feed_RuleConfigured(rule: AccountBlockingRule: [0x3Cff5E7eBecb676c3Cb602D0ef2d46710b88854E], configSalt: 0x0000000000000000000000000000000000000000000000000000000000000001, configParams: [])
    │   │   │   │   │   ├─ emit Lens_Feed_RuleSelectorEnabled(rule: AccountBlockingRule: [0x3Cff5E7eBecb676c3Cb602D0ef2d46710b88854E], configSalt: 0x0000000000000000000000000000000000000000000000000000000000000001, isRequired: true, ruleSelector: 0xf8748c20)
    │   │   │   │   │   └─ ← [Stop]
    │   │   │   │   └─ ← [Return]
    │   │   │   ├─ [5148] BeaconProxy::fallback([])
    │   │   │   │   ├─ [668] Beacon::implementation() [staticcall]
    │   │   │   │   │   └─ ← [Return] Feed: [0xa0Cb889707d426A7A386870A03bc70d1b0697598]
    │   │   │   │   ├─ [2907] Feed::setExtraData([]) [delegatecall]
    │   │   │   │   │   ├─ [1032] PermissionlessAccessControl::hasAccess(TransparentUpgradeableProxy: [0x3381cD18e2Fb4dB236BF0525938AB6E43Db0440f], BeaconProxy: [0x84331fdf4F2974B3Cb6D8003584CE74f62599F38], 70240964901469819303340425463478853942631622821288580975892518941391166957354 [7.024e76]) [staticcall]
    │   │   │   │   │   │   └─ ← [Return] true
    │   │   │   │   │   └─ ← [Stop]
    │   │   │   │   └─ ← [Return]
    │   │   │   ├─ [12232] BeaconProxy::fallback(OwnerAdminOnlyAccessControl: [0x1ad9e72CD508c47cDd24165E79F93D0d97dB888d])
    │   │   │   │   ├─ [668] Beacon::implementation() [staticcall]
    │   │   │   │   │   └─ ← [Return] Feed: [0xa0Cb889707d426A7A386870A03bc70d1b0697598]
    │   │   │   │   ├─ [9994] Feed::setAccessControl(OwnerAdminOnlyAccessControl: [0x1ad9e72CD508c47cDd24165E79F93D0d97dB888d]) [delegatecall]
    │   │   │   │   │   ├─ [887] PermissionlessAccessControl::canChangeAccessControl(TransparentUpgradeableProxy: [0x3381cD18e2Fb4dB236BF0525938AB6E43Db0440f], BeaconProxy: [0x84331fdf4F2974B3Cb6D8003584CE74f62599F38]) [staticcall]
    │   │   │   │   │   │   └─ ← [Return] true
    │   │   │   │   │   ├─ [3396] OwnerAdminOnlyAccessControl::hasAccess(BeaconProxy: [0x84331fdf4F2974B3Cb6D8003584CE74f62599F38], BeaconProxy: [0x84331fdf4F2974B3Cb6D8003584CE74f62599F38], 1) [staticcall]
    │   │   │   │   │   │   └─ ← [Return] false
    │   │   │   │   │   ├─ [360] OwnerAdminOnlyAccessControl::getType() [staticcall]
    │   │   │   │   │   │   └─ ← [Return] 0x366c180b93c016d94aa781dd984842068840b0dc26dec0c4bf64de7c26ee02bb
    │   │   │   │   │   ├─ emit Lens_AccessControlUpdated(accessControl: OwnerAdminOnlyAccessControl: [0x1ad9e72CD508c47cDd24165E79F93D0d97dB888d], accessControlType: 0x366c180b93c016d94aa781dd984842068840b0dc26dec0c4bf64de7c26ee02bb)
    │   │   │   │   │   └─ ← [Stop]
    │   │   │   │   └─ ← [Return]
    │   │   │   ├─ emit Lens_FeedFactory_Deployment(feed: BeaconProxy: [0x84331fdf4F2974B3Cb6D8003584CE74f62599F38], metadataURI: "uri://any")
    │   │   │   └─ ← [Return] BeaconProxy: [0x84331fdf4F2974B3Cb6D8003584CE74f62599F38]
    │   │   └─ ← [Return] BeaconProxy: [0x84331fdf4F2974B3Cb6D8003584CE74f62599F38]
    │   └─ ← [Return] BeaconProxy: [0x84331fdf4F2974B3Cb6D8003584CE74f62599F38]
    ├─ [3787232] LensFactory::deployNamespace("bitcoin", "satoshi://nakamoto", EventsTest: [0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496], [], [], [], "Bitcoin", "BTC")
    │   ├─ [1409272] AccessControlFactory::deployOwnerAdminOnlyAccessControl(EventsTest: [0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496], [])
    │   │   ├─ [1319029] → new OwnerAdminOnlyAccessControl@0xf84CEc75C47c3a69C16d6d48c68Ba0FACCCeB575
    │   │   │   ├─ emit Lens_Contract_Deployed(indexedContractType: 0x64617ee3c6a0361a9a8223334a8f2dacd3fe2087125e4536dd1d8f73178934e8, indexedFlavour: 0x8a77be47894bc95246876669e852d75c5320ba0a5ff56a0429873be5430d1f44, contractType: "access-control", flavour: "lens.access-control.owner-admin-only-access-control")
    │   │   │   ├─ emit Lens_AccessControl_RoleGranted(account: AccessControlFactory: [0x92a6649Fdcc044DA968d94202465578a9371C7b1], roleId: 30805062194276299293655310260615960901372458835523149434691481342518336257662 [3.08e76])
    │   │   │   ├─ emit Lens_AccessControl_AccessAdded(roleId: 30805062194276299293655310260615960901372458835523149434691481342518336257662 [3.08e76], contractAddress: 0x0000000000000000000000000000000000000000, permissionId: 0, granted: true)
    │   │   │   ├─ emit Lens_AccessControl_AccessAdded(roleId: 114319738593337656181689926536180396990758527023329145853867225489060618038901 [1.143e77], contractAddress: 0x0000000000000000000000000000000000000000, permissionId: 0, granted: true)
    │   │   │   └─ ← [Return] 5969 bytes of code
    │   │   ├─ emit Lens_AccessControlFactory_OwnerAdminDeployment(accessControl: OwnerAdminOnlyAccessControl: [0xf84CEc75C47c3a69C16d6d48c68Ba0FACCCeB575], owner: EventsTest: [0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496])
    │   │   ├─ [52481] OwnerAdminOnlyAccessControl::transferOwnership(EventsTest: [0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496])
    │   │   │   ├─ emit Lens_AccessControl_RoleRevoked(account: AccessControlFactory: [0x92a6649Fdcc044DA968d94202465578a9371C7b1], roleId: 30805062194276299293655310260615960901372458835523149434691481342518336257662 [3.08e76])
    │   │   │   ├─ emit Lens_AccessControl_RoleGranted(account: EventsTest: [0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496], roleId: 30805062194276299293655310260615960901372458835523149434691481342518336257662 [3.08e76])
    │   │   │   ├─ emit Lens_OwnershipTransferred(previousOwner: AccessControlFactory: [0x92a6649Fdcc044DA968d94202465578a9371C7b1], newOwner: EventsTest: [0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496])
    │   │   │   └─ ← [Stop]
    │   │   └─ ← [Return] OwnerAdminOnlyAccessControl: [0xf84CEc75C47c3a69C16d6d48c68Ba0FACCCeB575]
    │   ├─ [317606] → new LensUsernameTokenURIProvider@0xd01a8884b2aBA72E146Ab867B4d5880814bb6230
    │   │   ├─ emit Lens_Contract_Deployed(indexedContractType: 0xbf1e12f844536c694f637eeb1c5d30750741a46be650ade6f09f76cda08be40e, indexedFlavour: 0x3a9f616ebfff760f8cf8a4d5dc8d661ade11caae0a74ddf2d6abc50e6948343c, contractType: "username-token-uri-provider", flavour: "lens.username.token-uri-provider")
    │   │   └─ ← [Return] 1566 bytes of code
    │   ├─ [2012784] NamespaceFactory::deployNamespace("bitcoin", "satoshi://nakamoto", OwnerAdminOnlyAccessControl: [0xf84CEc75C47c3a69C16d6d48c68Ba0FACCCeB575], EventsTest: [0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496], [RuleChange({ ruleAddress: 0x796f2974e3C1af763252512dd6d521E9E984726C, configSalt: 0x0000000000000000000000000000000000000000000000000000000000000000, configurationChanges: RuleConfigurationChange({ configure: true, ruleParams: [] }), selectorChanges: [RuleSelectorChange({ ruleSelector: 0xe82196d5, isRequired: true, enabled: true })] })], [], "Bitcoin", "BTC", LensUsernameTokenURIProvider: [0xd01a8884b2aBA72E146Ab867B4d5880814bb6230])
    │   │   ├─ [668668] → new ProxyAdmin@0xf4a78db59e1cD9eF1fF98b56D1CD0119713e6009
    │   │   │   ├─ emit OwnershipTransferred(previousOwner: 0x0000000000000000000000000000000000000000, newOwner: EventsTest: [0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496])
    │   │   │   ├─ [472] Lock::isLocked() [staticcall]
    │   │   │   │   └─ ← [Return] true
    │   │   │   └─ ← [Return] 3212 bytes of code
    │   │   ├─ [878165] → new BeaconProxy@0xe0874ACbd34b8CE1678C843bb4C9000Cb7b95385
    │   │   │   ├─ emit AdminChanged(previousAdmin: 0x0000000000000000000000000000000000000000, newAdmin: ProxyAdmin: [0xf4a78db59e1cD9eF1fF98b56D1CD0119713e6009])
    │   │   │   ├─ emit AutoUpgradeChanged(enabled: true)
    │   │   │   ├─ emit BeaconUpgraded(beacon: Beacon: [0xD16d567549A2a2a2005aEACf7fB193851603dd70])
    │   │   │   ├─ [4668] Beacon::implementation() [staticcall]
    │   │   │   │   └─ ← [Return] Namespace: [0x03A6a84cD762D9707A21605b548aaaB891562aAb]
    │   │   │   ├─ emit Upgraded(implementation: Namespace: [0x03A6a84cD762D9707A21605b548aaaB891562aAb])
    │   │   │   └─ ← [Return] 3873 bytes of code
    │   │   ├─ [189844] BeaconProxy::fallback("bitcoin", "satoshi://nakamoto", "Bitcoin", "BTC", LensUsernameTokenURIProvider: [0xd01a8884b2aBA72E146Ab867B4d5880814bb6230], PermissionlessAccessControl: [0xFb02F4fa07b34d7a3587051169EE9E18D237263C])
    │   │   │   ├─ [668] Beacon::implementation() [staticcall]
    │   │   │   │   └─ ← [Return] Namespace: [0x03A6a84cD762D9707A21605b548aaaB891562aAb]
    │   │   │   ├─ [185016] Namespace::initialize("bitcoin", "satoshi://nakamoto", "Bitcoin", "BTC", LensUsernameTokenURIProvider: [0xd01a8884b2aBA72E146Ab867B4d5880814bb6230], PermissionlessAccessControl: [0xFb02F4fa07b34d7a3587051169EE9E18D237263C]) [delegatecall]
    │   │   │   │   ├─ emit Lens_Namespace_MetadataURISet(metadataURI: "satoshi://nakamoto")
    │   │   │   │   ├─ emit Lens_PermissionId_Available(permissionId: 38466158132835170259124534014582147097694553473091316621073709598217750698359 [3.846e76], name: "lens.permission.ChangeRules")
    │   │   │   │   ├─ emit Lens_PermissionId_Available(permissionId: 103155344723252794140333994655397123942861665251273923900803877733460157067242 [1.031e77], name: "lens.permission.SetMetadata")
    │   │   │   │   ├─ emit Lens_PermissionId_Available(permissionId: 70240964901469819303340425463478853942631622821288580975892518941391166957354 [7.024e76], name: "lens.permission.SetExtraData")
    │   │   │   │   ├─ emit Lens_PermissionId_Available(permissionId: 22932605848472111067709133488219603674481317031041746999355332445794474906729 [2.293e76], name: "lens.permission.SetTokenURIProvider")
    │   │   │   │   ├─ emit Lens_Contract_Deployed(indexedContractType: 0x300f800aee223ec4f0f7f13ec0e9fb1b8a8186bbfdb275780ce6218872155189, indexedFlavour: 0x9c294f20d702777bb2e4461358db373fe0b9f8903ec576d597d11acf2d376843, contractType: "namespace", flavour: "lens.namespace")
    │   │   │   │   ├─ [1032] PermissionlessAccessControl::hasAccess(BeaconProxy: [0xe0874ACbd34b8CE1678C843bb4C9000Cb7b95385], BeaconProxy: [0xe0874ACbd34b8CE1678C843bb4C9000Cb7b95385], 1) [staticcall]
    │   │   │   │   │   └─ ← [Return] true
    │   │   │   │   ├─ [315] PermissionlessAccessControl::getType() [staticcall]
    │   │   │   │   │   └─ ← [Return] 0xb5440aae9cc7331e30d1f5f4d93e4b545e210d2a6887783d935991d99a3c4dae
    │   │   │   │   ├─ emit Lens_AccessControlAdded(accessControl: PermissionlessAccessControl: [0xFb02F4fa07b34d7a3587051169EE9E18D237263C], accessControlType: 0xb5440aae9cc7331e30d1f5f4d93e4b545e210d2a6887783d935991d99a3c4dae)
    │   │   │   │   ├─ emit Lens_ERC721_TokenURIProviderSet(tokenURIProvider: LensUsernameTokenURIProvider: [0xd01a8884b2aBA72E146Ab867B4d5880814bb6230])
    │   │   │   │   └─ ← [Stop]
    │   │   │   └─ ← [Return]
    │   │   ├─ [175836] BeaconProxy::fallback([RuleChange({ ruleAddress: 0x796f2974e3C1af763252512dd6d521E9E984726C, configSalt: 0x0000000000000000000000000000000000000000000000000000000000000000, configurationChanges: RuleConfigurationChange({ configure: true, ruleParams: [] }), selectorChanges: [RuleSelectorChange({ ruleSelector: 0xe82196d5, isRequired: true, enabled: true })] })])
    │   │   │   ├─ [668] Beacon::implementation() [staticcall]
    │   │   │   │   └─ ← [Return] Namespace: [0x03A6a84cD762D9707A21605b548aaaB891562aAb]
    │   │   │   ├─ [173508] Namespace::changeNamespaceRules([RuleChange({ ruleAddress: 0x796f2974e3C1af763252512dd6d521E9E984726C, configSalt: 0x0000000000000000000000000000000000000000000000000000000000000000, configurationChanges: RuleConfigurationChange({ configure: true, ruleParams: [] }), selectorChanges: [RuleSelectorChange({ ruleSelector: 0xe82196d5, isRequired: true, enabled: true })] })]) [delegatecall]
    │   │   │   │   ├─ [1032] PermissionlessAccessControl::hasAccess(NamespaceFactory: [0xe8dc788818033232EF9772CB2e6622F1Ec8bc840], BeaconProxy: [0xe0874ACbd34b8CE1678C843bb4C9000Cb7b95385], 38466158132835170259124534014582147097694553473091316621073709598217750698359 [3.846e76]) [staticcall]
    │   │   │   │   │   └─ ← [Return] true
    │   │   │   │   ├─ [679] UsernameSimpleCharsetNamespaceRule::configure(0x0000000000000000000000000000000000000000000000000000000000000001, [])
    │   │   │   │   │   └─ ← [Stop]
    │   │   │   │   ├─ emit Lens_Namespace_RuleConfigured(rule: UsernameSimpleCharsetNamespaceRule: [0x796f2974e3C1af763252512dd6d521E9E984726C], configSalt: 0x0000000000000000000000000000000000000000000000000000000000000001, configParams: [])
    │   │   │   │   ├─ emit Lens_Namespace_RuleSelectorEnabled(rule: UsernameSimpleCharsetNamespaceRule: [0x796f2974e3C1af763252512dd6d521E9E984726C], configSalt: 0x0000000000000000000000000000000000000000000000000000000000000001, isRequired: true, ruleSelector: 0xe82196d5)
    │   │   │   │   └─ ← [Stop]
    │   │   │   └─ ← [Return]
    │   │   ├─ [5148] BeaconProxy::fallback([])
    │   │   │   ├─ [668] Beacon::implementation() [staticcall]
    │   │   │   │   └─ ← [Return] Namespace: [0x03A6a84cD762D9707A21605b548aaaB891562aAb]
    │   │   │   ├─ [2907] Namespace::setExtraData([]) [delegatecall]
    │   │   │   │   ├─ [1032] PermissionlessAccessControl::hasAccess(NamespaceFactory: [0xe8dc788818033232EF9772CB2e6622F1Ec8bc840], BeaconProxy: [0xe0874ACbd34b8CE1678C843bb4C9000Cb7b95385], 70240964901469819303340425463478853942631622821288580975892518941391166957354 [7.024e76]) [staticcall]
    │   │   │   │   │   └─ ← [Return] true
    │   │   │   │   └─ ← [Stop]
    │   │   │   └─ ← [Return]
    │   │   ├─ [12254] BeaconProxy::fallback(OwnerAdminOnlyAccessControl: [0xf84CEc75C47c3a69C16d6d48c68Ba0FACCCeB575])
    │   │   │   ├─ [668] Beacon::implementation() [staticcall]
    │   │   │   │   └─ ← [Return] Namespace: [0x03A6a84cD762D9707A21605b548aaaB891562aAb]
    │   │   │   ├─ [10016] Namespace::setAccessControl(OwnerAdminOnlyAccessControl: [0xf84CEc75C47c3a69C16d6d48c68Ba0FACCCeB575]) [delegatecall]
    │   │   │   │   ├─ [887] PermissionlessAccessControl::canChangeAccessControl(NamespaceFactory: [0xe8dc788818033232EF9772CB2e6622F1Ec8bc840], BeaconProxy: [0xe0874ACbd34b8CE1678C843bb4C9000Cb7b95385]) [staticcall]
    │   │   │   │   │   └─ ← [Return] true
    │   │   │   │   ├─ [3396] OwnerAdminOnlyAccessControl::hasAccess(BeaconProxy: [0xe0874ACbd34b8CE1678C843bb4C9000Cb7b95385], BeaconProxy: [0xe0874ACbd34b8CE1678C843bb4C9000Cb7b95385], 1) [staticcall]
    │   │   │   │   │   └─ ← [Return] false
    │   │   │   │   ├─ [360] OwnerAdminOnlyAccessControl::getType() [staticcall]
    │   │   │   │   │   └─ ← [Return] 0x366c180b93c016d94aa781dd984842068840b0dc26dec0c4bf64de7c26ee02bb
    │   │   │   │   ├─ emit Lens_AccessControlUpdated(accessControl: OwnerAdminOnlyAccessControl: [0xf84CEc75C47c3a69C16d6d48c68Ba0FACCCeB575], accessControlType: 0x366c180b93c016d94aa781dd984842068840b0dc26dec0c4bf64de7c26ee02bb)
    │   │   │   │   └─ ← [Stop]
    │   │   │   └─ ← [Return]
    │   │   ├─ emit Lens_NamespaceFactory_Deployment(namespaceAddress: BeaconProxy: [0xe0874ACbd34b8CE1678C843bb4C9000Cb7b95385], namespace: "bitcoin", metadataURI: "satoshi://nakamoto")
    │   │   └─ ← [Return] BeaconProxy: [0xe0874ACbd34b8CE1678C843bb4C9000Cb7b95385]
    │   └─ ← [Return] BeaconProxy: [0xe0874ACbd34b8CE1678C843bb4C9000Cb7b95385]
    ├─ [3324402] LensFactory::deployGraph("uri://any", EventsTest: [0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496], [], [], [])
    │   ├─ [1409272] AccessControlFactory::deployOwnerAdminOnlyAccessControl(EventsTest: [0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496], [])
    │   │   ├─ [1319029] → new OwnerAdminOnlyAccessControl@0x1FBba922bCeD749E3b88843A403f709b88fc14D8
    │   │   │   ├─ emit Lens_Contract_Deployed(indexedContractType: 0x64617ee3c6a0361a9a8223334a8f2dacd3fe2087125e4536dd1d8f73178934e8, indexedFlavour: 0x8a77be47894bc95246876669e852d75c5320ba0a5ff56a0429873be5430d1f44, contractType: "access-control", flavour: "lens.access-control.owner-admin-only-access-control")
    │   │   │   ├─ emit Lens_AccessControl_RoleGranted(account: AccessControlFactory: [0x92a6649Fdcc044DA968d94202465578a9371C7b1], roleId: 30805062194276299293655310260615960901372458835523149434691481342518336257662 [3.08e76])
    │   │   │   ├─ emit Lens_AccessControl_AccessAdded(roleId: 30805062194276299293655310260615960901372458835523149434691481342518336257662 [3.08e76], contractAddress: 0x0000000000000000000000000000000000000000, permissionId: 0, granted: true)
    │   │   │   ├─ emit Lens_AccessControl_AccessAdded(roleId: 114319738593337656181689926536180396990758527023329145853867225489060618038901 [1.143e77], contractAddress: 0x0000000000000000000000000000000000000000, permissionId: 0, granted: true)
    │   │   │   └─ ← [Return] 5969 bytes of code
    │   │   ├─ emit Lens_AccessControlFactory_OwnerAdminDeployment(accessControl: OwnerAdminOnlyAccessControl: [0x1FBba922bCeD749E3b88843A403f709b88fc14D8], owner: EventsTest: [0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496])
    │   │   ├─ [52481] OwnerAdminOnlyAccessControl::transferOwnership(EventsTest: [0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496])
    │   │   │   ├─ emit Lens_AccessControl_RoleRevoked(account: AccessControlFactory: [0x92a6649Fdcc044DA968d94202465578a9371C7b1], roleId: 30805062194276299293655310260615960901372458835523149434691481342518336257662 [3.08e76])
    │   │   │   ├─ emit Lens_AccessControl_RoleGranted(account: EventsTest: [0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496], roleId: 30805062194276299293655310260615960901372458835523149434691481342518336257662 [3.08e76])
    │   │   │   ├─ emit Lens_OwnershipTransferred(previousOwner: AccessControlFactory: [0x92a6649Fdcc044DA968d94202465578a9371C7b1], newOwner: EventsTest: [0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496])
    │   │   │   └─ ← [Stop]
    │   │   └─ ← [Return] OwnerAdminOnlyAccessControl: [0x1FBba922bCeD749E3b88843A403f709b88fc14D8]
    │   ├─ [1903729] GraphFactory::deployGraph("uri://any", OwnerAdminOnlyAccessControl: [0x1FBba922bCeD749E3b88843A403f709b88fc14D8], EventsTest: [0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496], [RuleChange({ ruleAddress: 0x3Cff5E7eBecb676c3Cb602D0ef2d46710b88854E, configSalt: 0x0000000000000000000000000000000000000000000000000000000000000000, configurationChanges: RuleConfigurationChange({ configure: true, ruleParams: [] }), selectorChanges: [RuleSelectorChange({ ruleSelector: 0x29d8fa41, isRequired: true, enabled: true })] })], [])
    │   │   ├─ [668668] → new ProxyAdmin@0xE748aec1d9e6477F82B231539c21Ffe56FE5f168
    │   │   │   ├─ emit OwnershipTransferred(previousOwner: 0x0000000000000000000000000000000000000000, newOwner: EventsTest: [0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496])
    │   │   │   ├─ [472] Lock::isLocked() [staticcall]
    │   │   │   │   └─ ← [Return] true
    │   │   │   └─ ← [Return] 3212 bytes of code
    │   │   ├─ [878165] → new BeaconProxy@0x0e16A9dC103fdD00794C0f13F19bCaDC292D80ba
    │   │   │   ├─ emit AdminChanged(previousAdmin: 0x0000000000000000000000000000000000000000, newAdmin: ProxyAdmin: [0xE748aec1d9e6477F82B231539c21Ffe56FE5f168])
    │   │   │   ├─ emit AutoUpgradeChanged(enabled: true)
    │   │   │   ├─ emit BeaconUpgraded(beacon: Beacon: [0x2a07706473244BC757E10F2a9E86fB532828afe3])
    │   │   │   ├─ [4668] Beacon::implementation() [staticcall]
    │   │   │   │   └─ ← [Return] Graph: [0x1d1499e622D69689cdf9004d05Ec547d650Ff211]
    │   │   │   ├─ emit Upgraded(implementation: Graph: [0x1d1499e622D69689cdf9004d05Ec547d650Ff211])
    │   │   │   └─ ← [Return] 3873 bytes of code
    │   │   ├─ [93341] BeaconProxy::fallback("uri://any", PermissionlessAccessControl: [0x514dd0Bcaf5994Ef889f482B79d39D18B6E4363F])
    │   │   │   ├─ [668] Beacon::implementation() [staticcall]
    │   │   │   │   └─ ← [Return] Graph: [0x1d1499e622D69689cdf9004d05Ec547d650Ff211]
    │   │   │   ├─ [88594] Graph::initialize("uri://any", PermissionlessAccessControl: [0x514dd0Bcaf5994Ef889f482B79d39D18B6E4363F]) [delegatecall]
    │   │   │   │   ├─ emit Lens_Graph_MetadataURISet(metadataURI: "uri://any")
    │   │   │   │   ├─ emit Lens_PermissionId_Available(permissionId: 38466158132835170259124534014582147097694553473091316621073709598217750698359 [3.846e76], name: "lens.permission.ChangeRules")
    │   │   │   │   ├─ emit Lens_PermissionId_Available(permissionId: 103155344723252794140333994655397123942861665251273923900803877733460157067242 [1.031e77], name: "lens.permission.SetMetadata")
    │   │   │   │   ├─ emit Lens_PermissionId_Available(permissionId: 70240964901469819303340425463478853942631622821288580975892518941391166957354 [7.024e76], name: "lens.permission.SetExtraData")
    │   │   │   │   ├─ emit Lens_Contract_Deployed(indexedContractType: 0xa0ed527785244825d33465d49867f1f6bf4936894648395a2a06d501921477b4, indexedFlavour: 0x765f60ccc8a421fba3a06ca3f86a13d8c69a4bbcaa1c7ce7759a1bc52b73a6e9, contractType: "graph", flavour: "lens.graph")
    │   │   │   │   ├─ [1032] PermissionlessAccessControl::hasAccess(BeaconProxy: [0x0e16A9dC103fdD00794C0f13F19bCaDC292D80ba], BeaconProxy: [0x0e16A9dC103fdD00794C0f13F19bCaDC292D80ba], 1) [staticcall]
    │   │   │   │   │   └─ ← [Return] true
    │   │   │   │   ├─ [315] PermissionlessAccessControl::getType() [staticcall]
    │   │   │   │   │   └─ ← [Return] 0xb5440aae9cc7331e30d1f5f4d93e4b545e210d2a6887783d935991d99a3c4dae
    │   │   │   │   ├─ emit Lens_AccessControlAdded(accessControl: PermissionlessAccessControl: [0x514dd0Bcaf5994Ef889f482B79d39D18B6E4363F], accessControlType: 0xb5440aae9cc7331e30d1f5f4d93e4b545e210d2a6887783d935991d99a3c4dae)
    │   │   │   │   └─ ← [Stop]
    │   │   │   └─ ← [Return]
    │   │   ├─ [168178] BeaconProxy::fallback([RuleChange({ ruleAddress: 0x3Cff5E7eBecb676c3Cb602D0ef2d46710b88854E, configSalt: 0x0000000000000000000000000000000000000000000000000000000000000000, configurationChanges: RuleConfigurationChange({ configure: true, ruleParams: [] }), selectorChanges: [RuleSelectorChange({ ruleSelector: 0x29d8fa41, isRequired: true, enabled: true })] })])
    │   │   │   ├─ [668] Beacon::implementation() [staticcall]
    │   │   │   │   └─ ← [Return] Graph: [0x1d1499e622D69689cdf9004d05Ec547d650Ff211]
    │   │   │   ├─ [165850] Graph::changeGraphRules([RuleChange({ ruleAddress: 0x3Cff5E7eBecb676c3Cb602D0ef2d46710b88854E, configSalt: 0x0000000000000000000000000000000000000000000000000000000000000000, configurationChanges: RuleConfigurationChange({ configure: true, ruleParams: [] }), selectorChanges: [RuleSelectorChange({ ruleSelector: 0x29d8fa41, isRequired: true, enabled: true })] })]) [delegatecall]
    │   │   │   │   ├─ [1032] PermissionlessAccessControl::hasAccess(GraphFactory: [0x756e0562323ADcDA4430d6cb456d9151f605290B], BeaconProxy: [0x0e16A9dC103fdD00794C0f13F19bCaDC292D80ba], 38466158132835170259124534014582147097694553473091316621073709598217750698359 [3.846e76]) [staticcall]
    │   │   │   │   │   └─ ← [Return] true
    │   │   │   │   ├─ [724] AccountBlockingRule::configure(0x0000000000000000000000000000000000000000000000000000000000000001, [])
    │   │   │   │   │   └─ ← [Stop]
    │   │   │   │   ├─ emit Lens_Graph_RuleConfigured(rule: AccountBlockingRule: [0x3Cff5E7eBecb676c3Cb602D0ef2d46710b88854E], configSalt: 0x0000000000000000000000000000000000000000000000000000000000000001, configParams: [])
    │   │   │   │   ├─ emit Lens_Graph_RuleSelectorEnabled(rule: AccountBlockingRule: [0x3Cff5E7eBecb676c3Cb602D0ef2d46710b88854E], configSalt: 0x0000000000000000000000000000000000000000000000000000000000000001, isRequired: true, ruleSelector: 0x29d8fa41)
    │   │   │   │   └─ ← [Stop]
    │   │   │   └─ ← [Return]
    │   │   ├─ [5081] BeaconProxy::fallback([])
    │   │   │   ├─ [668] Beacon::implementation() [staticcall]
    │   │   │   │   └─ ← [Return] Graph: [0x1d1499e622D69689cdf9004d05Ec547d650Ff211]
    │   │   │   ├─ [2840] Graph::setExtraData([]) [delegatecall]
    │   │   │   │   ├─ [1032] PermissionlessAccessControl::hasAccess(GraphFactory: [0x756e0562323ADcDA4430d6cb456d9151f605290B], BeaconProxy: [0x0e16A9dC103fdD00794C0f13F19bCaDC292D80ba], 70240964901469819303340425463478853942631622821288580975892518941391166957354 [7.024e76]) [staticcall]
    │   │   │   │   │   └─ ← [Return] true
    │   │   │   │   └─ ← [Stop]
    │   │   │   └─ ← [Return]
    │   │   ├─ [12232] BeaconProxy::fallback(OwnerAdminOnlyAccessControl: [0x1FBba922bCeD749E3b88843A403f709b88fc14D8])
    │   │   │   ├─ [668] Beacon::implementation() [staticcall]
    │   │   │   │   └─ ← [Return] Graph: [0x1d1499e622D69689cdf9004d05Ec547d650Ff211]
    │   │   │   ├─ [9994] Graph::setAccessControl(OwnerAdminOnlyAccessControl: [0x1FBba922bCeD749E3b88843A403f709b88fc14D8]) [delegatecall]
    │   │   │   │   ├─ [887] PermissionlessAccessControl::canChangeAccessControl(GraphFactory: [0x756e0562323ADcDA4430d6cb456d9151f605290B], BeaconProxy: [0x0e16A9dC103fdD00794C0f13F19bCaDC292D80ba]) [staticcall]
    │   │   │   │   │   └─ ← [Return] true
    │   │   │   │   ├─ [3396] OwnerAdminOnlyAccessControl::hasAccess(BeaconProxy: [0x0e16A9dC103fdD00794C0f13F19bCaDC292D80ba], BeaconProxy: [0x0e16A9dC103fdD00794C0f13F19bCaDC292D80ba], 1) [staticcall]
    │   │   │   │   │   └─ ← [Return] false
    │   │   │   │   ├─ [360] OwnerAdminOnlyAccessControl::getType() [staticcall]
    │   │   │   │   │   └─ ← [Return] 0x366c180b93c016d94aa781dd984842068840b0dc26dec0c4bf64de7c26ee02bb
    │   │   │   │   ├─ emit Lens_AccessControlUpdated(accessControl: OwnerAdminOnlyAccessControl: [0x1FBba922bCeD749E3b88843A403f709b88fc14D8], accessControlType: 0x366c180b93c016d94aa781dd984842068840b0dc26dec0c4bf64de7c26ee02bb)
    │   │   │   │   └─ ← [Stop]
    │   │   │   └─ ← [Return]
    │   │   ├─ emit Lens_GraphFactory_Deployment(graph: BeaconProxy: [0x0e16A9dC103fdD00794C0f13F19bCaDC292D80ba], metadataURI: "uri://any")
    │   │   └─ ← [Return] BeaconProxy: [0x0e16A9dC103fdD00794C0f13F19bCaDC292D80ba]
    │   └─ ← [Return] BeaconProxy: [0x0e16A9dC103fdD00794C0f13F19bCaDC292D80ba]
    ├─ [3546345] LensFactory::deployApp("uri://any", false, EventsTest: [0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496], [], AppInitialProperties({ graph: 0x0e16A9dC103fdD00794C0f13F19bCaDC292D80ba, feeds: [0x84331fdf4F2974B3Cb6D8003584CE74f62599F38], namespace: 0xe0874ACbd34b8CE1678C843bb4C9000Cb7b95385, groups: [], defaultFeed: 0x84331fdf4F2974B3Cb6D8003584CE74f62599F38, signers: [], paymaster: 0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496, treasury: 0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496 }), [])
    │   ├─ [1409272] AccessControlFactory::deployOwnerAdminOnlyAccessControl(EventsTest: [0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496], [])
    │   │   ├─ [1319029] → new OwnerAdminOnlyAccessControl@0xbFB1339122657D0720D7964799cF9adD1169D2bA
    │   │   │   ├─ emit Lens_Contract_Deployed(indexedContractType: 0x64617ee3c6a0361a9a8223334a8f2dacd3fe2087125e4536dd1d8f73178934e8, indexedFlavour: 0x8a77be47894bc95246876669e852d75c5320ba0a5ff56a0429873be5430d1f44, contractType: "access-control", flavour: "lens.access-control.owner-admin-only-access-control")
    │   │   │   ├─ emit Lens_AccessControl_RoleGranted(account: AccessControlFactory: [0x92a6649Fdcc044DA968d94202465578a9371C7b1], roleId: 30805062194276299293655310260615960901372458835523149434691481342518336257662 [3.08e76])
    │   │   │   ├─ emit Lens_AccessControl_AccessAdded(roleId: 30805062194276299293655310260615960901372458835523149434691481342518336257662 [3.08e76], contractAddress: 0x0000000000000000000000000000000000000000, permissionId: 0, granted: true)
    │   │   │   ├─ emit Lens_AccessControl_AccessAdded(roleId: 114319738593337656181689926536180396990758527023329145853867225489060618038901 [1.143e77], contractAddress: 0x0000000000000000000000000000000000000000, permissionId: 0, granted: true)
    │   │   │   └─ ← [Return] 5969 bytes of code
    │   │   ├─ emit Lens_AccessControlFactory_OwnerAdminDeployment(accessControl: OwnerAdminOnlyAccessControl: [0xbFB1339122657D0720D7964799cF9adD1169D2bA], owner: EventsTest: [0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496])
    │   │   ├─ [52481] OwnerAdminOnlyAccessControl::transferOwnership(EventsTest: [0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496])
    │   │   │   ├─ emit Lens_AccessControl_RoleRevoked(account: AccessControlFactory: [0x92a6649Fdcc044DA968d94202465578a9371C7b1], roleId: 30805062194276299293655310260615960901372458835523149434691481342518336257662 [3.08e76])
    │   │   │   ├─ emit Lens_AccessControl_RoleGranted(account: EventsTest: [0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496], roleId: 30805062194276299293655310260615960901372458835523149434691481342518336257662 [3.08e76])
    │   │   │   ├─ emit Lens_OwnershipTransferred(previousOwner: AccessControlFactory: [0x92a6649Fdcc044DA968d94202465578a9371C7b1], newOwner: EventsTest: [0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496])
    │   │   │   └─ ← [Stop]
    │   │   └─ ← [Return] OwnerAdminOnlyAccessControl: [0xbFB1339122657D0720D7964799cF9adD1169D2bA]
    │   ├─ [2125793] AppFactory::deployApp("uri://any", false, OwnerAdminOnlyAccessControl: [0xbFB1339122657D0720D7964799cF9adD1169D2bA], EventsTest: [0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496], AppInitialProperties({ graph: 0x0e16A9dC103fdD00794C0f13F19bCaDC292D80ba, feeds: [0x84331fdf4F2974B3Cb6D8003584CE74f62599F38], namespace: 0xe0874ACbd34b8CE1678C843bb4C9000Cb7b95385, groups: [], defaultFeed: 0x84331fdf4F2974B3Cb6D8003584CE74f62599F38, signers: [], paymaster: 0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496, treasury: 0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496 }), [])
    │   │   ├─ [668668] → new ProxyAdmin@0xfA0e6015e8AD40Aa4535C477142a2eCdb824F2f7
    │   │   │   ├─ emit OwnershipTransferred(previousOwner: 0x0000000000000000000000000000000000000000, newOwner: EventsTest: [0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496])
    │   │   │   ├─ [472] Lock::isLocked() [staticcall]
    │   │   │   │   └─ ← [Return] true
    │   │   │   └─ ← [Return] 3212 bytes of code
    │   │   ├─ [878165] → new BeaconProxy@0x1a7420135e3551169cf51251e77C21eCaB8fBff7
    │   │   │   ├─ emit AdminChanged(previousAdmin: 0x0000000000000000000000000000000000000000, newAdmin: ProxyAdmin: [0xfA0e6015e8AD40Aa4535C477142a2eCdb824F2f7])
    │   │   │   ├─ emit AutoUpgradeChanged(enabled: true)
    │   │   │   ├─ emit BeaconUpgraded(beacon: Beacon: [0xD6BbDE9174b1CdAa358d2Cf4D57D1a9F7178FBfF])
    │   │   │   ├─ [4668] Beacon::implementation() [staticcall]
    │   │   │   │   └─ ← [Return] App: [0x5991A2dF15A8F6A256D3Ec51E99254Cd3fb576A9]
    │   │   │   ├─ emit Upgraded(implementation: App: [0x5991A2dF15A8F6A256D3Ec51E99254Cd3fb576A9])
    │   │   │   └─ ← [Return] 3873 bytes of code
    │   │   ├─ [501385] BeaconProxy::fallback("uri://any", false, OwnerAdminOnlyAccessControl: [0xbFB1339122657D0720D7964799cF9adD1169D2bA], AppInitialProperties({ graph: 0x0e16A9dC103fdD00794C0f13F19bCaDC292D80ba, feeds: [0x84331fdf4F2974B3Cb6D8003584CE74f62599F38], namespace: 0xe0874ACbd34b8CE1678C843bb4C9000Cb7b95385, groups: [], defaultFeed: 0x84331fdf4F2974B3Cb6D8003584CE74f62599F38, signers: [], paymaster: 0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496, treasury: 0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496 }), [])
    │   │   │   ├─ [668] Beacon::implementation() [staticcall]
    │   │   │   │   └─ ← [Return] App: [0x5991A2dF15A8F6A256D3Ec51E99254Cd3fb576A9]
    │   │   │   ├─ [496542] App::initialize("uri://any", false, OwnerAdminOnlyAccessControl: [0xbFB1339122657D0720D7964799cF9adD1169D2bA], AppInitialProperties({ graph: 0x0e16A9dC103fdD00794C0f13F19bCaDC292D80ba, feeds: [0x84331fdf4F2974B3Cb6D8003584CE74f62599F38], namespace: 0xe0874ACbd34b8CE1678C843bb4C9000Cb7b95385, groups: [], defaultFeed: 0x84331fdf4F2974B3Cb6D8003584CE74f62599F38, signers: [], paymaster: 0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496, treasury: 0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496 }), []) [delegatecall]
    │   │   │   │   ├─ emit Lens_App_MetadataURISet(metadataURI: "uri://any")
    │   │   │   │   ├─ emit Lens_App_SourceStampVerificationSet(isEnabled: false)
    │   │   │   │   ├─ emit Lens_App_TreasurySet(treasury: EventsTest: [0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496])
    │   │   │   │   ├─ emit Lens_App_GraphAdded(graph: BeaconProxy: [0x0e16A9dC103fdD00794C0f13F19bCaDC292D80ba])
    │   │   │   │   ├─ emit Lens_App_FeedAdded(feed: BeaconProxy: [0x84331fdf4F2974B3Cb6D8003584CE74f62599F38])
    │   │   │   │   ├─ emit Lens_App_NamespaceAdded(namespace: BeaconProxy: [0xe0874ACbd34b8CE1678C843bb4C9000Cb7b95385])
    │   │   │   │   ├─ emit Lens_App_DefaultFeedSet(feed: BeaconProxy: [0x84331fdf4F2974B3Cb6D8003584CE74f62599F38])
    │   │   │   │   ├─ emit Lens_App_PaymasterAdded(paymaster: EventsTest: [0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496])
    │   │   │   │   ├─ emit Lens_PermissionId_Available(permissionId: 19853587705464295720862099991442612527294953575292425624813249820309812225198 [1.985e76], name: "SET_PRIMITIVES")
    │   │   │   │   ├─ emit Lens_PermissionId_Available(permissionId: 56538665293339356869230938266952898205048649617711334352871450992602834158162 [5.653e76], name: "SET_SIGNERS")
    │   │   │   │   ├─ emit Lens_PermissionId_Available(permissionId: 41710970067000748588985441154206345396663581351719076122104573545008091125764 [4.171e76], name: "SET_TREASURY")
    │   │   │   │   ├─ emit Lens_PermissionId_Available(permissionId: 15845365780032349410493998763993378866870330427535449653405787904302849439626 [1.584e76], name: "SET_PAYMASTER")
    │   │   │   │   ├─ emit Lens_PermissionId_Available(permissionId: 70240964901469819303340425463478853942631622821288580975892518941391166957354 [7.024e76], name: "SET_EXTRA_DATA")
    │   │   │   │   ├─ emit Lens_PermissionId_Available(permissionId: 103155344723252794140333994655397123942861665251273923900803877733460157067242 [1.031e77], name: "SET_METADATA")
    │   │   │   │   ├─ emit Lens_PermissionId_Available(permissionId: 61201934193436299899834775837630870019732640639032095236653403782209397879953 [6.12e76], name: "SET_SOURCE_STAMP_VERIFICATION")
    │   │   │   │   ├─ emit Lens_Contract_Deployed(indexedContractType: 0xd6f028ca0e8edb4a8c9757ca4fdccab25fa1e0317da1188108f7d2dee14902fb, indexedFlavour: 0xb644ea971c98f8dc41d555fc3b11d338987098465306763b436e4edc9b747825, contractType: "app", flavour: "lens.app")
    │   │   │   │   ├─ [3396] OwnerAdminOnlyAccessControl::hasAccess(BeaconProxy: [0x1a7420135e3551169cf51251e77C21eCaB8fBff7], BeaconProxy: [0x1a7420135e3551169cf51251e77C21eCaB8fBff7], 1) [staticcall]
    │   │   │   │   │   └─ ← [Return] false
    │   │   │   │   ├─ [360] OwnerAdminOnlyAccessControl::getType() [staticcall]
    │   │   │   │   │   └─ ← [Return] 0x366c180b93c016d94aa781dd984842068840b0dc26dec0c4bf64de7c26ee02bb
    │   │   │   │   ├─ emit Lens_AccessControlAdded(accessControl: OwnerAdminOnlyAccessControl: [0xbFB1339122657D0720D7964799cF9adD1169D2bA], accessControlType: 0x366c180b93c016d94aa781dd984842068840b0dc26dec0c4bf64de7c26ee02bb)
    │   │   │   │   └─ ← [Stop]
    │   │   │   └─ ← [Return]
    │   │   ├─ emit Lens_AppFactory_Deployment(app: BeaconProxy: [0x1a7420135e3551169cf51251e77C21eCaB8fBff7], metadataURI: "uri://any", extraData: [])
    │   │   └─ ← [Return] BeaconProxy: [0x1a7420135e3551169cf51251e77C21eCaB8fBff7]
    │   └─ ← [Return] BeaconProxy: [0x1a7420135e3551169cf51251e77C21eCaB8fBff7]
    ├─ [119089] BeaconProxy::fallback(EventsTest: [0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496], "satoshi", [], [], [])
    │   ├─ [668] Beacon::implementation() [staticcall]
    │   │   └─ ← [Return] Namespace: [0x03A6a84cD762D9707A21605b548aaaB891562aAb]
    │   ├─ [116785] Namespace::createUsername(EventsTest: [0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496], "satoshi", [], [], []) [delegatecall]
    │   │   ├─ emit Transfer(from: 0x0000000000000000000000000000000000000000, to: EventsTest: [0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496], tokenId: 26399243466107690849926285425218995470903144188285154912385881930680602484506 [2.639e76])
    │   │   ├─ emit Lens_Username_Transfer(from: 0x0000000000000000000000000000000000000000, to: EventsTest: [0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496], tokenId: 26399243466107690849926285425218995470903144188285154912385881930680602484506 [2.639e76])
    │   │   ├─ [1346] EventsTest::onERC721Received(EventsTest: [0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496], 0x0000000000000000000000000000000000000000, 26399243466107690849926285425218995470903144188285154912385881930680602484506 [2.639e76], 0x)
    │   │   │   └─ ← [Return] 0x150b7a02
    │   │   ├─ [3674] UsernameSimpleCharsetNamespaceRule::processCreation(0x0000000000000000000000000000000000000000000000000000000000000001, EventsTest: [0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496], EventsTest: [0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496], "satoshi", [], [])
    │   │   │   └─ ← [Stop]
    │   │   ├─ emit Lens_Username_Created(username: "satoshi", account: EventsTest: [0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496], customParams: [], ruleProcessingParams: [], source: 0x0000000000000000000000000000000000000000, extraData: [])
    │   │   └─ ← [Stop]
    │   └─ ← [Return]
    ├─ [1943252] LensFactory::createAccountWithUsernameFree(BeaconProxy: [0xe0874ACbd34b8CE1678C843bb4C9000Cb7b95385], CreateAccountParams({ metadataURI: "uri://any", owner: 0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496, accountManagers: [], accountManagersPermissions: [], accountCreationSourceStamp: SourceStamp({ source: 0x1a7420135e3551169cf51251e77C21eCaB8fBff7, nonce: 0, deadline: 1001, signature: 0x }), accountExtraData: [] }), CreateUsernameParams({ username: "notsatoshi", createUsernameCustomParams: [], createUsernameRuleProcessingParams: [], assignUsernameCustomParams: [], unassignAccountRuleProcessingParams: [], assignRuleProcessingParams: [], usernameExtraData: [] }))
    │   ├─ [1714581] AccountFactory::deployAccount(LensFactory: [0xDA5A5ADC64C8013d334A0DA9e711B364Af7A4C2d], "uri://any", [], [], SourceStamp({ source: 0x1a7420135e3551169cf51251e77C21eCaB8fBff7, nonce: 0, deadline: 1001, signature: 0x }), [])
    │   │   ├─ [668668] → new ProxyAdmin@0x618AEaC155Df3Fd190057af6671482ed7AF4882B
    │   │   │   ├─ emit OwnershipTransferred(previousOwner: 0x0000000000000000000000000000000000000000, newOwner: LensFactory: [0xDA5A5ADC64C8013d334A0DA9e711B364Af7A4C2d])
    │   │   │   ├─ [472] Lock::isLocked() [staticcall]
    │   │   │   │   └─ ← [Return] true
    │   │   │   └─ ← [Return] 3212 bytes of code
    │   │   ├─ [878165] → new BeaconProxy@0x85244bc2da45b84698a3F605a1CfA71a1b799E52
    │   │   │   ├─ emit AdminChanged(previousAdmin: 0x0000000000000000000000000000000000000000, newAdmin: ProxyAdmin: [0x618AEaC155Df3Fd190057af6671482ed7AF4882B])
    │   │   │   ├─ emit AutoUpgradeChanged(enabled: true)
    │   │   │   ├─ emit BeaconUpgraded(beacon: Beacon: [0x15cF58144EF33af1e14b5208015d11F9143E27b9])
    │   │   │   ├─ [4668] Beacon::implementation() [staticcall]
    │   │   │   │   └─ ← [Return] Account: [0xc7183455a4C133Ae270771860664b6B7ec320bB1]
    │   │   │   ├─ emit Upgraded(implementation: Account: [0xc7183455a4C133Ae270771860664b6B7ec320bB1])
    │   │   │   └─ ← [Return] 3873 bytes of code
    │   │   ├─ [90242] BeaconProxy::fallback(LensFactory: [0xDA5A5ADC64C8013d334A0DA9e711B364Af7A4C2d], "uri://any", [], [], SourceStamp({ source: 0x1a7420135e3551169cf51251e77C21eCaB8fBff7, nonce: 0, deadline: 1001, signature: 0x }), [])
    │   │   │   ├─ [668] Beacon::implementation() [staticcall]
    │   │   │   │   └─ ← [Return] Account: [0xc7183455a4C133Ae270771860664b6B7ec320bB1]
    │   │   │   ├─ [85423] Account::initialize(LensFactory: [0xDA5A5ADC64C8013d334A0DA9e711B364Af7A4C2d], "uri://any", [], [], SourceStamp({ source: 0x1a7420135e3551169cf51251e77C21eCaB8fBff7, nonce: 0, deadline: 1001, signature: 0x }), []) [delegatecall]
    │   │   │   │   ├─ [2922] BeaconProxy::fallback(SourceStamp({ source: 0x1a7420135e3551169cf51251e77C21eCaB8fBff7, nonce: 0, deadline: 1001, signature: 0x }))
    │   │   │   │   │   ├─ [668] Beacon::implementation() [staticcall]
    │   │   │   │   │   │   └─ ← [Return] App: [0x5991A2dF15A8F6A256D3Ec51E99254Cd3fb576A9]
    │   │   │   │   │   ├─ [663] App::validateSource(SourceStamp({ source: 0x1a7420135e3551169cf51251e77C21eCaB8fBff7, nonce: 0, deadline: 1001, signature: 0x })) [delegatecall]
    │   │   │   │   │   │   └─ ← [Stop]
    │   │   │   │   │   └─ ← [Return]
    │   │   │   │   ├─ emit Lens_Account_MetadataURISet(metadataURI: "uri://any")
    │   │   │   │   ├─ emit Lens_Contract_Deployed(indexedContractType: 0xd844bb55167ab332117049e2ccd3d8863d241bcc80f46302310a6d942a90e851, indexedFlavour: 0x7eaa217dd2b0f18f9a91473ea81ad439320de60cf37a533f7fb00c9488d5c267, contractType: "account", flavour: "lens.account")
    │   │   │   │   ├─ emit OwnershipTransferred(previousOwner: 0x0000000000000000000000000000000000000000, newOwner: LensFactory: [0xDA5A5ADC64C8013d334A0DA9e711B364Af7A4C2d])
    │   │   │   │   ├─ emit Lens_Account_OwnerTransferred(newOwner: LensFactory: [0xDA5A5ADC64C8013d334A0DA9e711B364Af7A4C2d])
    │   │   │   │   └─ ← [Stop]
    │   │   │   └─ ← [Return]
    │   │   ├─ emit Lens_Account_Created(account: BeaconProxy: [0x85244bc2da45b84698a3F605a1CfA71a1b799E52], owner: LensFactory: [0xDA5A5ADC64C8013d334A0DA9e711B364Af7A4C2d], metadataURI: "uri://any", accountManagers: [], accountManagersPermissions: [], source: BeaconProxy: [0x1a7420135e3551169cf51251e77C21eCaB8fBff7], extraData: [])
    │   │   └─ ← [Return] BeaconProxy: [0x85244bc2da45b84698a3F605a1CfA71a1b799E52]
    │   ├─ [132605] BeaconProxy::fallback(BeaconProxy: [0xe0874ACbd34b8CE1678C843bb4C9000Cb7b95385], 0, 0xa1eaa4dc00000000000000000000000085244bc2da45b84698a3f605a1cfa71a1b799e5200000000000000000000000000000000000000000000000000000000000000a000000000000000000000000000000000000000000000000000000000000000e000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000120000000000000000000000000000000000000000000000000000000000000000a6e6f747361746f73686900000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000)
    │   │   ├─ [668] Beacon::implementation() [staticcall]
    │   │   │   └─ ← [Return] Account: [0xc7183455a4C133Ae270771860664b6B7ec320bB1]
    │   │   ├─ [130286] Account::executeTransaction(BeaconProxy: [0xe0874ACbd34b8CE1678C843bb4C9000Cb7b95385], 0, 0xa1eaa4dc00000000000000000000000085244bc2da45b84698a3f605a1cfa71a1b799e5200000000000000000000000000000000000000000000000000000000000000a000000000000000000000000000000000000000000000000000000000000000e000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000120000000000000000000000000000000000000000000000000000000000000000a6e6f747361746f73686900000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000) [delegatecall]
    │   │   │   ├─ [122220] BeaconProxy::fallback(BeaconProxy: [0x85244bc2da45b84698a3F605a1CfA71a1b799E52], "notsatoshi", [], [], [])
    │   │   │   │   ├─ [668] Beacon::implementation() [staticcall]
    │   │   │   │   │   └─ ← [Return] Namespace: [0x03A6a84cD762D9707A21605b548aaaB891562aAb]
    │   │   │   │   ├─ [119916] Namespace::createUsername(BeaconProxy: [0x85244bc2da45b84698a3F605a1CfA71a1b799E52], "notsatoshi", [], [], []) [delegatecall]
    │   │   │   │   │   ├─ emit Transfer(from: 0x0000000000000000000000000000000000000000, to: BeaconProxy: [0x85244bc2da45b84698a3F605a1CfA71a1b799E52], tokenId: 9435037226528369397580729660645977810177139598997241430948086516734578480339 [9.435e75])
    │   │   │   │   │   ├─ emit Lens_Username_Transfer(from: 0x0000000000000000000000000000000000000000, to: BeaconProxy: [0x85244bc2da45b84698a3F605a1CfA71a1b799E52], tokenId: 9435037226528369397580729660645977810177139598997241430948086516734578480339 [9.435e75])
    │   │   │   │   │   ├─ [3580] BeaconProxy::fallback(BeaconProxy: [0x85244bc2da45b84698a3F605a1CfA71a1b799E52], 0x0000000000000000000000000000000000000000, 9435037226528369397580729660645977810177139598997241430948086516734578480339 [9.435e75], 0x)
    │   │   │   │   │   │   ├─ [668] Beacon::implementation() [staticcall]
    │   │   │   │   │   │   │   └─ ← [Return] Account: [0xc7183455a4C133Ae270771860664b6B7ec320bB1]
    │   │   │   │   │   │   ├─ [1324] Account::onERC721Received(BeaconProxy: [0x85244bc2da45b84698a3F605a1CfA71a1b799E52], 0x0000000000000000000000000000000000000000, 9435037226528369397580729660645977810177139598997241430948086516734578480339 [9.435e75], 0x) [delegatecall]
    │   │   │   │   │   │   │   └─ ← [Return] 0x150b7a02
    │   │   │   │   │   │   └─ ← [Return] 0x150b7a02
    │   │   │   │   │   ├─ [4571] UsernameSimpleCharsetNamespaceRule::processCreation(0x0000000000000000000000000000000000000000000000000000000000000001, BeaconProxy: [0x85244bc2da45b84698a3F605a1CfA71a1b799E52], BeaconProxy: [0x85244bc2da45b84698a3F605a1CfA71a1b799E52], "notsatoshi", [], [])
    │   │   │   │   │   │   └─ ← [Stop]
    │   │   │   │   │   ├─ emit Lens_Username_Created(username: "notsatoshi", account: BeaconProxy: [0x85244bc2da45b84698a3F605a1CfA71a1b799E52], customParams: [], ruleProcessingParams: [], source: 0x0000000000000000000000000000000000000000, extraData: [])
    │   │   │   │   │   └─ ← [Stop]
    │   │   │   │   └─ ← [Return]
    │   │   │   ├─ emit Lens_Account_TransactionExecuted(to: BeaconProxy: [0xe0874ACbd34b8CE1678C843bb4C9000Cb7b95385], value: 0, data: 0xa1eaa4dc00000000000000000000000085244bc2da45b84698a3f605a1cfa71a1b799e5200000000000000000000000000000000000000000000000000000000000000a000000000000000000000000000000000000000000000000000000000000000e000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000120000000000000000000000000000000000000000000000000000000000000000a6e6f747361746f73686900000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000, executor: LensFactory: [0xDA5A5ADC64C8013d334A0DA9e711B364Af7A4C2d])
    │   │   │   └─ ← [Return] 0x
    │   │   └─ ← [Return] 0x
    │   ├─ [72548] BeaconProxy::fallback(BeaconProxy: [0xe0874ACbd34b8CE1678C843bb4C9000Cb7b95385], 0, 0x4df53b2700000000000000000000000085244bc2da45b84698a3f605a1cfa71a1b799e5200000000000000000000000000000000000000000000000000000000000000c00000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000012000000000000000000000000000000000000000000000000000000000000001400000000000000000000000000000000000000000000000000000000000000160000000000000000000000000000000000000000000000000000000000000000a6e6f747361746f736869000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000)
    │   │   ├─ [668] Beacon::implementation() [staticcall]
    │   │   │   └─ ← [Return] Account: [0xc7183455a4C133Ae270771860664b6B7ec320bB1]
    │   │   ├─ [70217] Account::executeTransaction(BeaconProxy: [0xe0874ACbd34b8CE1678C843bb4C9000Cb7b95385], 0, 0x4df53b2700000000000000000000000085244bc2da45b84698a3f605a1cfa71a1b799e5200000000000000000000000000000000000000000000000000000000000000c00000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000012000000000000000000000000000000000000000000000000000000000000001400000000000000000000000000000000000000000000000000000000000000160000000000000000000000000000000000000000000000000000000000000000a6e6f747361746f736869000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000) [delegatecall]
    │   │   │   ├─ [61608] BeaconProxy::fallback(BeaconProxy: [0x85244bc2da45b84698a3F605a1CfA71a1b799E52], "notsatoshi", [], [], [], [])
    │   │   │   │   ├─ [668] Beacon::implementation() [staticcall]
    │   │   │   │   │   └─ ← [Return] Namespace: [0x03A6a84cD762D9707A21605b548aaaB891562aAb]
    │   │   │   │   ├─ [59313] Namespace::assignUsername(BeaconProxy: [0x85244bc2da45b84698a3F605a1CfA71a1b799E52], "notsatoshi", [], [], [], []) [delegatecall]
    │   │   │   │   │   ├─ emit Lens_Username_Assigned(username: "notsatoshi", account: BeaconProxy: [0x85244bc2da45b84698a3F605a1CfA71a1b799E52], customParams: [], ruleProcessingParams: [], source: 0x0000000000000000000000000000000000000000)
    │   │   │   │   │   └─ ← [Stop]
    │   │   │   │   └─ ← [Return]
    │   │   │   ├─ emit Lens_Account_TransactionExecuted(to: BeaconProxy: [0xe0874ACbd34b8CE1678C843bb4C9000Cb7b95385], value: 0, data: 0x4df53b2700000000000000000000000085244bc2da45b84698a3f605a1cfa71a1b799e5200000000000000000000000000000000000000000000000000000000000000c00000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000012000000000000000000000000000000000000000000000000000000000000001400000000000000000000000000000000000000000000000000000000000000160000000000000000000000000000000000000000000000000000000000000000a6e6f747361746f736869000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000, executor: LensFactory: [0xDA5A5ADC64C8013d334A0DA9e711B364Af7A4C2d])
    │   │   │   └─ ← [Return] 0x
    │   │   └─ ← [Return] 0x
    │   ├─ [6287] BeaconProxy::fallback(EventsTest: [0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496])
    │   │   ├─ [668] Beacon::implementation() [staticcall]
    │   │   │   └─ ← [Return] Account: [0xc7183455a4C133Ae270771860664b6B7ec320bB1]
    │   │   ├─ [4028] Account::transferOwnership(EventsTest: [0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496]) [delegatecall]
    │   │   │   ├─ emit OwnershipTransferred(previousOwner: LensFactory: [0xDA5A5ADC64C8013d334A0DA9e711B364Af7A4C2d], newOwner: EventsTest: [0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496])
    │   │   │   ├─ emit Lens_Account_OwnerTransferred(newOwner: EventsTest: [0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496])
    │   │   │   └─ ← [Stop]
    │   │   └─ ← [Return]
    │   └─ ← [Return] BeaconProxy: [0x85244bc2da45b84698a3F605a1CfA71a1b799E52]
    ├─ [0] VM::addr(<pk>) [staticcall]
    │   └─ ← [Return] FOLLOWER: [0xC376B9D02f9a0B627e1999Cf62dA791aBb477356]
    ├─ [0] VM::label(FOLLOWER: [0xC376B9D02f9a0B627e1999Cf62dA791aBb477356], "FOLLOWER")
    │   └─ ← [Return]
    ├─ [0] VM::addr(<pk>) [staticcall]
    │   └─ ← [Return] TARGET: [0xeD4b6816cFe277027f72ed83a53A1a7F3D46059B]
    ├─ [0] VM::label(TARGET: [0xeD4b6816cFe277027f72ed83a53A1a7F3D46059B], "TARGET")
    │   └─ ← [Return]
    ├─ [0] VM::prank(FOLLOWER: [0xC376B9D02f9a0B627e1999Cf62dA791aBb477356])
    │   └─ ← [Return]
    ├─ [160883] BeaconProxy::fallback(FOLLOWER: [0xC376B9D02f9a0B627e1999Cf62dA791aBb477356], TARGET: [0xeD4b6816cFe277027f72ed83a53A1a7F3D46059B], [], [], [], [])
    │   ├─ [668] Beacon::implementation() [staticcall]
    │   │   └─ ← [Return] Graph: [0x1d1499e622D69689cdf9004d05Ec547d650Ff211]
    │   ├─ [158576] Graph::follow(FOLLOWER: [0xC376B9D02f9a0B627e1999Cf62dA791aBb477356], TARGET: [0xeD4b6816cFe277027f72ed83a53A1a7F3D46059B], [], [], [], []) [delegatecall]
    │   │   ├─ [3922] AccountBlockingRule::processFollow(0x0000000000000000000000000000000000000000000000000000000000000001, FOLLOWER: [0xC376B9D02f9a0B627e1999Cf62dA791aBb477356], FOLLOWER: [0xC376B9D02f9a0B627e1999Cf62dA791aBb477356], TARGET: [0xeD4b6816cFe277027f72ed83a53A1a7F3D46059B], [], [])
    │   │   │   └─ ← [Stop]
    │   │   ├─ emit Lens_Graph_Followed(followerAccount: FOLLOWER: [0xC376B9D02f9a0B627e1999Cf62dA791aBb477356], accountToFollow: TARGET: [0xeD4b6816cFe277027f72ed83a53A1a7F3D46059B], followId: 1, customParams: [], graphRulesProcessingParams: [], followRulesProcessingParams: [], source: 0x0000000000000000000000000000000000000000, extraData: [])
    │   │   └─ ← [Return] 1
    │   └─ ← [Return] 1
    ├─ [0] VM::prank(FOLLOWER: [0xC376B9D02f9a0B627e1999Cf62dA791aBb477356])
    │   └─ ← [Return]
    ├─ [12873] BeaconProxy::fallback(FOLLOWER: [0xC376B9D02f9a0B627e1999Cf62dA791aBb477356], TARGET: [0xeD4b6816cFe277027f72ed83a53A1a7F3D46059B], [], [])
    │   ├─ [668] Beacon::implementation() [staticcall]
    │   │   └─ ← [Return] Graph: [0x1d1499e622D69689cdf9004d05Ec547d650Ff211]
    │   ├─ [10590] Graph::unfollow(FOLLOWER: [0xC376B9D02f9a0B627e1999Cf62dA791aBb477356], TARGET: [0xeD4b6816cFe277027f72ed83a53A1a7F3D46059B], [], []) [delegatecall]
    │   │   ├─ emit Lens_Graph_Unfollowed(followerAccount: FOLLOWER: [0xC376B9D02f9a0B627e1999Cf62dA791aBb477356], accountToUnfollow: TARGET: [0xeD4b6816cFe277027f72ed83a53A1a7F3D46059B], followId: 1, customParams: [], graphRulesProcessingParams: [], source: 0x0000000000000000000000000000000000000000)
    │   │   └─ ← [Return] 1
    │   └─ ← [Return] 1
    ├─ [248192] BeaconProxy::fallback(CreatePostParams({ author: 0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496, contentURI: "content", repostedPostId: 0, quotedPostId: 0, repliedPostId: 0, ruleChanges: [], extraData: [] }), [], [], [], [])
    │   ├─ [668] Beacon::implementation() [staticcall]
    │   │   └─ ← [Return] Feed: [0xa0Cb889707d426A7A386870A03bc70d1b0697598]
    │   ├─ [245846] Feed::createPost(CreatePostParams({ author: 0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496, contentURI: "content", repostedPostId: 0, quotedPostId: 0, repliedPostId: 0, ruleChanges: [], extraData: [] }), [], [], [], []) [delegatecall]
    │   │   ├─ emit Lens_ExtraDataSet(addr: 0x0000000000000000000000000000000000000000, entityId: 32024048300109861314495673281101631534065137348136835261884125178093993571509 [3.202e76], key: 0x3cd0f450c58e5572a9f19a4af172d526fb9645ba11a751c1e6fe7f53c4d956eb, value: 0x0000000000000000000000000000000000000000000000000000000000000000)
    │   │   ├─ [1326] AccountBlockingRule::processCreatePost(0x0000000000000000000000000000000000000000000000000000000000000001, 32024048300109861314495673281101631534065137348136835261884125178093993571509 [3.202e76], CreatePostParams({ author: 0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496, contentURI: "content", repostedPostId: 0, quotedPostId: 0, repliedPostId: 0, ruleChanges: [], extraData: [] }), [], [])
    │   │   │   └─ ← [Stop]
    │   │   ├─ emit Lens_Feed_PostCreated(postId: 32024048300109861314495673281101631534065137348136835261884125178093993571509 [3.202e76], author: EventsTest: [0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496], localSequentialId: 1, rootPostId: 32024048300109861314495673281101631534065137348136835261884125178093993571509 [3.202e76], postParams: CreatePostParams({ author: 0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496, contentURI: "content", repostedPostId: 0, quotedPostId: 0, repliedPostId: 0, ruleChanges: [], extraData: [] }), customParams: [], feedRulesParams: [], rootPostRulesParams: [], quotedPostRulesParams: [], source: 0x0000000000000000000000000000000000000000)
    │   │   └─ ← [Return] 32024048300109861314495673281101631534065137348136835261884125178093993571509 [3.202e76]
    │   └─ ← [Return] 32024048300109861314495673281101631534065137348136835261884125178093993571509 [3.202e76]
    └─ ← [Stop]

Suite result: ok. 2 passed; 0 failed; 0 skipped; finished in 8.33ms (2.66ms CPU time)
