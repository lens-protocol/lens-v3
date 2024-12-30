//////////////////////////////////// Permissions ////////////////////////////////////

// Definition:
keccak256("lens.permission.{permissionName}");

// Examples:
keccak256("lens.permission.SkipPayments");
keccak256("lens.permission.ChangeRules");
keccak256("lens.permission.BanMembers");

//////////////////////////////////// Custom Params ////////////////////////////////////

// Definition:
keccak256("lens.param.{paramName}");

// Examples:
keccak256("lens.param.accessControl"); 
keccak256("lens.param.sourceStamp"); 

//////////////////////////////////// Extra data ////////////////////////////////////

// Definition:
keccak256("lens.data.{extraDataKey}"); 

// Examples:
keccak256("lens.data.groupFeed"); 
keccak256("lens.data.source");

//////////////////////////////////// Roles ////////////////////////////////////

// Definition:
keccak256("lens.role.{roleId}"); 

// Examples:
keccak256("lens.role.Owner"); 
keccak256("lens.role.Admin"); 

//////////////////////////////////// Storage ////////////////////////////////////

// Definition:
keccak256("lens.storage.{contractType}.{storedObject}");

// Examples:
keccak256("lens.storage.AccessControl.roles");

//////////////////////////////////// Contract Type ////////////////////////////////////

// Definition:
keccak256("lens.contract.{contractType}[.{subType}]"); 

// Examples:
keccak256("lens.contract.AccessControl.OwnerAdminOnlyAccessControl"); 
keccak256("lens.contract.AccessControl.RoleBasedAccessControl"); 
