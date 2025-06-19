-- Clean schema for PortFlow system (no auto-drop, no origin/destination)

-- Drop triggers only if needed
DROP TRIGGER IF EXISTS set_last_updated ON portflow_containers;
DROP FUNCTION IF EXISTS update_last_updated_column();

-- Create container table
CREATE TABLE IF NOT EXISTS portflow_containers (
    cont_id VARCHAR(20) PRIMARY KEY,
    cont_type VARCHAR(20) CHECK (cont_type IN ('20ft', '40ft')),
    cont_contents VARCHAR(100),
    cont_status VARCHAR(20) DEFAULT 'In Port',
    last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create transport table (without constraint if already exists)
CREATE TABLE IF NOT EXISTS portflow_transports (
    transport_id SERIAL PRIMARY KEY,
    cont_id VARCHAR(20) REFERENCES portflow_containers(cont_id) ON DELETE CASCADE,
    transport_type VARCHAR(10) CHECK (transport_type IN ('Ship', 'Truck', 'Rail')),
    carrier_name VARCHAR(100),
    departure_time TIMESTAMP,
    arrival_time TIMESTAMP,
    notes TEXT
);

-- Step 1: Remove exact duplicates (keep the one with smallest transport_id)
DELETE FROM portflow_transports t1
USING portflow_transports t2
WHERE t1.transport_id > t2.transport_id
  AND t1.cont_id = t2.cont_id
  AND t1.transport_type = t2.transport_type
  AND t1.carrier_name = t2.carrier_name
  AND t1.departure_time = t2.departure_time;

-- Step 2: Add unique constraint (now safe)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint 
        WHERE conname = 'unique_transport_entry'
        AND conrelid = 'portflow_transports'::regclass
    ) THEN
        ALTER TABLE portflow_transports
        ADD CONSTRAINT unique_transport_entry UNIQUE (cont_id, transport_type, carrier_name, departure_time);
    END IF;
END;
$$;

-- Trigger function to update last_updated timestamp
CREATE OR REPLACE FUNCTION update_last_updated_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.last_updated := NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger on update
CREATE TRIGGER set_last_updated
BEFORE UPDATE ON portflow_containers
FOR EACH ROW
EXECUTE FUNCTION update_last_updated_column();

-- Insert containers (ignores duplicates if cont_id already exists)
INSERT INTO portflow_containers (cont_id, cont_type, cont_contents)
VALUES 
    ('NYK1029384', '20ft', 'Pharmaceuticals'),
    ('EMC2093847', '40ft', 'Home Appliances'),
    ('HLC3847562', '20ft', 'Automobile Parts'),
    ('OOCL1122334', '40ft', 'Frozen Seafood'),
    ('APL5566778', '20ft', 'Smartphones'),
    ('ZIM9988776', '40ft', 'Furniture'),
    ('ONE4455667', '20ft', 'Chemicals'),
    ('MAE7766554', '40ft', 'Machinery Components')
ON CONFLICT (cont_id) DO NOTHING;

-- Insert transport records (prevent duplicates)
INSERT INTO portflow_transports (cont_id, transport_type, carrier_name, departure_time, arrival_time, notes)
VALUES
    ('NYK1029384', 'Truck', 'Blue Dart Express', '2024-05-01 07:00:00', '2024-05-01 12:30:00', 'Temperature-controlled delivery'),
    ('NYK1029384', 'Rail', 'Indian Rail Cargo', '2024-05-02 06:00:00', NULL, 'Awaiting departure from warehouse'),

    ('EMC2093847', 'Ship', 'Evergreen Marine', '2024-04-20 14:00:00', '2024-05-03 10:00:00', 'From Busan to Colombo'),

    ('HLC3847562', 'Truck', 'Delhivery Logistics', '2024-05-10 09:15:00', '2024-05-10 16:00:00', 'Delivered to regional hub'),
    ('HLC3847562', 'Rail', 'DB Cargo', '2024-05-11 07:00:00', NULL, 'Cross-border shipment to Italy'),

    ('OOCL1122334', 'Ship', 'OOCL Express', '2024-06-01 18:00:00', NULL, 'Departing from Yokohama'),
    ('OOCL1122334', 'Truck', 'Nippon Express', '2024-06-02 08:00:00', NULL, 'Transport to cold storage'),

    ('APL5566778', 'Rail', 'CSX Transportation', '2024-05-18 11:00:00', '2024-05-19 04:00:00', 'From New Jersey to Chicago'),

    ('ZIM9988776', 'Truck', 'XPO Logistics', '2024-05-22 07:45:00', NULL, 'En route to warehouse'),

    ('ONE4455667', 'Ship', 'ONE Ocean Network', '2024-04-30 15:00:00', '2024-05-14 09:30:00', 'Bulk chemical handling'),
    ('ONE4455667', 'Truck', 'RoadRunner Freight', '2024-05-14 13:00:00', NULL, 'Moving to chemical plant'),

    ('MAE7766554', 'Rail', 'Canadian National', '2024-05-05 06:30:00', '2024-05-06 20:00:00', 'Heavy industrial cargo delivery')
ON CONFLICT ON CONSTRAINT unique_transport_entry DO NOTHING;
