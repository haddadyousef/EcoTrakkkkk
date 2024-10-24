const express = require('express');
const app = express();
const PORT = process.env.PORT || 3000;

// Middleware to parse JSON bodies
app.use(express.json());

// In-memory leaderboard array
let leaderboard = [
  { name: "Alice", score: 120 },
  { name: "Bob", score: 80 },
  { name: "Charlie", score: 150 }
];

// Route to add new data to the leaderboard
app.post('/leaderboard', (req, res) => {
  const { name, score } = req.body;

  if (!name || typeof score !== 'number') {
    return res.status(400).send({ message: 'Name and score are required, and score must be a number!' });
  }

  // Find the index of the existing entry with the same name
  const existingIndex = leaderboard.findIndex(entry => entry.name === name);

  // If the entry exists, remove it from the leaderboard
  if (existingIndex !== -1) {
    leaderboard.splice(existingIndex, 1);
  }

  // Add new entry to leaderboard
  leaderboard.push({ name, score });

  // Sort leaderboard by score (ascending order)
  leaderboard.sort((a, b) => a.score - b.score);

  console.log('Updated leaderboard:', leaderboard); // Debug log

  res.send({ message: 'Score added!', leaderboard });
});

// Route to get the leaderboard data (JSON format)
app.get('/leaderboard', (req, res) => {
  res.json(leaderboard);
});

// Route to serve the leaderboard webpage
app.get('/', (req, res) => {
  const carbonEmissions = Math.floor(Math.random() * 1000); // Generate random carbon emission values
  let html = `
    <html>
    <head>
      <title>Leaderboard and Carbon Emissions</title>
      <style>
        body {
          font-family: Arial, sans-serif;
          margin: 40px;
        }
        h1 {
          color: #333;
        }
        table {
          width: 50%;
          margin-top: 20px;
          border-collapse: collapse;
        }
        th, td {
          padding: 10px;
          text-align: left;
          border: 1px solid #ddd;
        }
        th {
          background-color: #f4f4f4;
        }
      </style>
    </head>
    <body>
      <h1>Leaderboard</h1>
      <table id="leaderboard-table">
        <thead>
          <tr>
            <th>Name</th>
            <th>Score</th>
          </tr>
        </thead>
        <tbody id="leaderboard-body">`;

  // Add leaderboard entries to the HTML table
  leaderboard.forEach(entry => {
    html += `
      <tr>
        <td>${entry.name}</td>
        <td>${entry.score}</td>
      </tr>`;
  });

  html += `
        </tbody>
      </table>
      <h1>Carbon Emissions</h1>
      <p>Today's carbon emissions: <strong>${carbonEmissions} tons</strong></p>
      <script>
        function updateLeaderboard() {
          fetch('/leaderboard')
            .then(response => response.json())
            .then(data => {
              const tbody = document.getElementById('leaderboard-body');
              tbody.innerHTML = ''; // Clear existing rows
              data.forEach(entry => {
                const row = document.createElement('tr');
                row.innerHTML = '<td>' + entry.name + '</td><td>' + entry.score + '</td>';
                tbody.appendChild(row);
              });
            })
            .catch(error => console.error('Error fetching leaderboard:', error));
        }
        setInterval(updateLeaderboard, 5000); // Update leaderboard every 5 seconds
      </script>
    </body>
    </html>`;

  res.send(html); // Send the generated HTML as the response
});

// Start the server
app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});