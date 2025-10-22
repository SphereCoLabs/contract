import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

export default buildModule("SphereCoModule", (m) => {
  const sphereco = m.contract("SphereCo");

  return { sphereco };
});
