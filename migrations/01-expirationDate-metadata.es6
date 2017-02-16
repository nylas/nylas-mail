module.exports = {
  up: async (queryInterface, Sequelize) => {
    const {sequelize} = queryInterface;
    console.log("querying db");
    await sequelize.query("ALTER TABLE metadata ADD COLUMN `expiration` DATETIME");
  },
  down: async (queryInterface, Sequelize) => {
    const {sequelize} = queryInterface;
    await sequelize.query("ALTER TABLE metadata DROP COLUMN `expiration`");
  },
}
