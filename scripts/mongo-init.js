// MongoDB initialization script — runs on first container startup
db = db.getSiblingDB(process.env.MONGO_INITDB_DATABASE || 'goracabs');

// Create application user
db.createUser({
  user: process.env.MONGO_APP_USER || 'goraapp',
  pwd: process.env.MONGO_APP_PASSWORD || 'gorapassword',
  roles: [{ role: 'readWrite', db: process.env.MONGO_INITDB_DATABASE || 'goracabs' }],
});

print('MongoDB initialized for database: ' + db.getName());
