import SerializableRegistry from './serializable-registry';

class DatabaseObjectRegistry extends SerializableRegistry {}

const registry = new DatabaseObjectRegistry();
export default registry;
