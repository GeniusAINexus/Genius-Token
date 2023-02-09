var Genius = artifacts.require("Genius");

module.exports = function(deployer) {
  // deploy Genius with 7 parameters
  deployer.deploy(Genius, 
      "Genius", 
      "GENIUS", 
      true,
      25, 
      100, 
      0,
      '0x3ae64288e328Da761626147BaEba13d422A8114D'
      );
};
