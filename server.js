const express = require('express');
const cors = require('cors');
const path = require('path');
const fs = require('fs');
const config = require('./config');

const app = express();
const PORT = config.PORT;

app.use(cors());
app.use(express.json());
app.use(express.static(path.join(__dirname, 'public')));

const DATA_FILE = path.join(config.DATA_DIR, 'data', 'videos.json');

function ensureDataDir() {
  const dir = path.join(config.DATA_DIR, 'data');
  if (!fs.existsSync(dir)) {
    fs.mkdirSync(dir, { recursive: true });
  }
}

function loadVideos() {
  ensureDataDir();
  if (!fs.existsSync(DATA_FILE)) {
    return { videos: [] };
  }
  try {
    const content = fs.readFileSync(DATA_FILE, 'utf8');
    return JSON.parse(content);
  } catch (error) {
    console.error('Error loading videos:', error);
    return { videos: [] };
  }
}

function saveVideos(data) {
  ensureDataDir();
  fs.writeFileSync(DATA_FILE, JSON.stringify(data, null, 2), 'utf8');
}

function authenticate(req, res, next) {
  const authHeader = req.headers.authorization;
  if (!authHeader || authHeader !== `Bearer ${config.ADMIN_PASSWORD}`) {
    return res.status(401).json({ error: 'Unauthorized' });
  }
  next();
}

app.get('/api/videos', (req, res) => {
  const data = loadVideos();
  res.json(data.videos || []);
});

app.post('/api/videos', authenticate, (req, res) => {
  try {
    const data = loadVideos();
    const newVideo = {
      id: Date.now().toString(),
      videoId: req.body.videoId,
      title: req.body.title || '',
      description: req.body.description || '',
      module: req.body.module || '',
      createdAt: new Date().toISOString()
    };
    
    data.videos.push(newVideo);
    saveVideos(data);
    
    res.status(201).json(newVideo);
  } catch (error) {
    res.status(500).json({ error: 'Failed to save video' });
  }
});

app.put('/api/videos/:id', authenticate, (req, res) => {
  try {
    const data = loadVideos();
    const index = data.videos.findIndex(v => v.id === req.params.id);
    
    if (index === -1) {
      return res.status(404).json({ error: 'Video not found' });
    }
    
    data.videos[index] = {
      ...data.videos[index],
      ...req.body,
      id: data.videos[index].id,
      createdAt: data.videos[index].createdAt
    };
    
    saveVideos(data);
    res.json(data.videos[index]);
  } catch (error) {
    res.status(500).json({ error: 'Failed to update video' });
  }
});

app.delete('/api/videos/:id', authenticate, (req, res) => {
  try {
    const data = loadVideos();
    data.videos = data.videos.filter(v => v.id !== req.params.id);
    saveVideos(data);
    res.status(204).send();
  } catch (error) {
    res.status(500).json({ error: 'Failed to delete video' });
  }
});

app.get('/api/health', (req, res) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

app.listen(PORT, () => {
  console.log(`Velociclos API running on http://localhost:${PORT}`);
  console.log(`Admin panel: http://localhost:${PORT}/admin/index.html`);
  console.log(`Password: ${config.ADMIN_PASSWORD}`);
});
