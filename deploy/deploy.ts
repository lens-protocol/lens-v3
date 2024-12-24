import deployFactories from './deployFactories';
import { deployLensPrimitives, deployLensAccessControl, deployLensActionHub } from './deployAux';
import { deployRules } from './deployRules';
import { deployActions } from './deployActions';
import { generateEnvFile } from './lensUtils';

export default async function deploy() {
  await deployFactories();
  await deployLensPrimitives();
  const actionHub = await deployLensActionHub();
  await deployLensAccessControl();
  await deployRules();
  await deployActions(actionHub);
  generateEnvFile();
}
