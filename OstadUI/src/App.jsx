import { useState, useEffect } from 'react'
import './App.css'

function App() {
  const [message, setMessage] = useState('Loading...')
  const [items, setItems] = useState([])
  const [newItem, setNewItem] = useState({ name: '', description: '' })
  const [loading, setLoading] = useState(false)

  useEffect(() => {
    // Fetch server status
    fetch('http://localhost:5050')
      .then(response => response.json())
      .then(data => setMessage(data.message))
      .catch(error => setMessage('Error connecting to server'))
    
    // Fetch items from MongoDB
    fetchItems()
  }, [])

  const fetchItems = () => {
    fetch('http://localhost:5050/api/items')
      .then(response => response.json())
      .then(data => setItems(data))
      .catch(error => console.error('Error fetching items:', error))
  }

  const handleInputChange = (e) => {
    const { name, value } = e.target
    setNewItem({...newItem, [name]: value})
  }

  const handleSubmit = (e) => {
    e.preventDefault()
    setLoading(true)
    
    fetch('http://localhost:5050/api/items', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(newItem),
    })
      .then(response => response.json())
      .then(data => {
        setItems([...items, data])
        setNewItem({ name: '', description: '' })
        setLoading(false)
      })
      .catch(error => {
        console.error('Error adding item:', error)
        setLoading(false)
      })
  }

  return (
    <div className="App">
      <h1>Ostad UI</h1>
      <p className="server-status">Server Status: {message}</p>
      
      <div className="content">
        <div className="add-item-form">
          <h2>Add New Item</h2>
          <form onSubmit={handleSubmit}>
            <div className="form-group">
              <label htmlFor="name">Name:</label>
              <input 
                type="text" 
                id="name" 
                name="name" 
                value={newItem.name} 
                onChange={handleInputChange} 
                required 
              />
            </div>
            
            <div className="form-group">
              <label htmlFor="description">Description:</label>
              <textarea 
                id="description" 
                name="description" 
                value={newItem.description} 
                onChange={handleInputChange} 
                required 
              />
            </div>
            
            <button type="submit" disabled={loading}>
              {loading ? 'Adding...' : 'Add Item'}
            </button>
          </form>
        </div>
        
        <div className="items-list">
          <h2>Items from MongoDB</h2>
          {items.length === 0 ? (
            <p>No items found. Add your first item!</p>
          ) : (
            <ul>
              {items.map(item => (
                <li key={item._id}>
                  <strong>{item.name}</strong>
                  <p>{item.description}</p>
                  <small>Created: {new Date(item.createdAt).toLocaleString()}</small>
                </li>
              ))}
            </ul>
          )}
        </div>
      </div>
    </div>
  )
}

export default App
