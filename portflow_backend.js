const express = require('express');
const { Pool } = require('pg');
const cors = require('cors');
const app = express();
const PORT = 5001;

// Middleware
app.use(cors());
app.use(express.json());

const pool = new Pool({
    user: 'postgres',
    host: 'localhost',
    database: 'portflow_container_db',
    password: 'shamanth2005',
    port: 5432,
});

// GET all containers with their transports
app.get('/api/containers', async (req, res) => {
    try {
        const containers = await pool.query(`
            SELECT * FROM portflow_containers 
            ORDER BY last_updated DESC
        `);

        const containersWithTransports = await Promise.all(
            containers.rows.map(async container => {
                const transports = await pool.query(
                    'SELECT * FROM portflow_transports WHERE cont_id = $1 ORDER BY departure_time DESC',
                    [container.cont_id]
                );
                return {
                    ...container,
                    transports: transports.rows
                };
            })
        );

        res.json(containersWithTransports);
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// POST new container
app.post('/api/containers', async (req, res) => {
    const { id, type, contents, origin, destination } = req.body;
    try {
        await pool.query(
            'INSERT INTO portflow_containers (cont_id, cont_type, cont_contents, cont_origin, cont_destination) VALUES ($1, $2, $3, $4, $5)',
            [id, type, contents, origin || '', destination || '']
        );
        res.status(201).json({ 
            message: 'Container added!',
            container: {
                cont_id: id,
                cont_type: type,
                cont_contents: contents,
                cont_status: 'In Port',
                cont_origin: origin || '',
                cont_destination: destination || '',
                transports: []
            }
        });
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// PATCH update container status
app.patch('/api/containers/:id/status', async (req, res) => {
    const { status } = req.body;
    try {
        await pool.query(
            'UPDATE portflow_containers SET cont_status = $1, last_updated = NOW() WHERE cont_id = $2',
            [status, req.params.id]
        );
        res.json({ message: 'Status updated' });
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// DELETE container
app.delete('/api/containers/:id', async (req, res) => {
    try {
        await pool.query('DELETE FROM portflow_containers WHERE cont_id = $1', [req.params.id]);
        res.json({ message: 'Container deleted' });
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// POST new transport
app.post('/api/containers/:id/transports', async (req, res) => {
    const { transport_type, carrier_name, departure_time, arrival_time, notes } = req.body;
    try {
        const result = await pool.query(
            `INSERT INTO portflow_transports 
            (cont_id, transport_type, carrier_name, departure_time, arrival_time, notes) 
            VALUES ($1, $2, $3, $4, $5, $6) RETURNING *`,
            [req.params.id, transport_type, carrier_name, departure_time, arrival_time, notes]
        );
        res.status(201).json(result.rows[0]);
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// DELETE transport
app.delete('/api/transports/:id', async (req, res) => {
    try {
        await pool.query('DELETE FROM portflow_transports WHERE transport_id = $1', [req.params.id]);
        res.json({ message: 'Transport deleted' });
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});


// Start server
app.listen(PORT, () => {
    console.log(`Server running on http://localhost:${PORT}`);
});


