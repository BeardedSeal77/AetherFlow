'use client'

import { useState } from 'react'
import { useSortable } from '@dnd-kit/sortable'
import { CSS } from '@dnd-kit/utilities'

interface DriverTask {
  id: string;
  status: string;
  type: 'Deliver' | 'Collect' | 'Swap';
  equipment: string[];
  customer: string;
  company: string;
  address: string;
  booked: 'Yes' | 'No';
  driver: 'Yes' | 'No';
  qualityControl: 'Yes' | 'No';
  whatsapp: 'Yes' | 'No';
}

interface DriverItemProps {
  task: DriverTask;
  onUpdate?: (updatedTask: DriverTask) => void;
}

export default function DriverItem({ task, onUpdate }: DriverItemProps) {
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [editedTask, setEditedTask] = useState<DriverTask>({ ...task });
  const [equipmentVerified, setEquipmentVerified] = useState<Record<string, boolean>>(
    task.equipment.reduce((acc, item) => ({ ...acc, [item]: false }), {})
  );
  
  const {
    attributes,
    listeners,
    setNodeRef,
    transform,
    transition,
  } = useSortable({ 
    id: task.id,
    data: {
      type: 'driver',
      task,
    }
  })

  const style = {
    transform: CSS.Transform.toString(transform),
    transition,
  }

  // Calculate progress for status bar (0-4 based on Yes responses)
  const calculateProgress = () => {
    const statusItems = [task.booked, task.driver, task.qualityControl, task.whatsapp];
    return statusItems.filter(item => item === 'Yes').length;
  }
  
  const progress = calculateProgress();
  
  // Background gradient that rises with progress
  const getProgressBackground = () => {
    const progressPercent = (progress / 4) * 100;
    return `linear-gradient(to top, rgba(34, 197, 94, 0.3) ${progressPercent}%, transparent ${progressPercent}%)`;
  }

  // Get type badge color
  const getTypeBadgeColor = () => {
    switch(task.type) {
      case 'Deliver': return 'bg-green';
      case 'Collect': return 'bg-blue';
      case 'Swap': return 'bg-yellow';
      default: return 'bg-gray-500';
    }
  }

  // Handle double click to open modal
  const handleDoubleClick = () => {
    // Reset equipment verification state
    const initialVerificationState = editedTask.equipment.reduce(
      (acc, item) => ({ ...acc, [item]: false }), 
      {}
    );
    setEquipmentVerified(initialVerificationState);
    setIsModalOpen(true);
  }

  // Handle form input changes
  const handleInputChange = (field: keyof DriverTask, value: any) => {
    setEditedTask(prev => ({ ...prev, [field]: value }));
  }

  // Handle equipment input changes (convert comma-separated string to array)
  const handleEquipmentChange = (value: string) => {
    const equipmentArray = value.split(',').map(item => item.trim()).filter(item => item);
    
    // Update equipment verification state for new items
    const newVerificationState = equipmentArray.reduce(
      (acc, item) => ({
        ...acc,
        [item]: equipmentVerified[item] || false
      }),
      {}
    );
    
    setEquipmentVerified(newVerificationState);
    setEditedTask(prev => ({ ...prev, equipment: equipmentArray }));
  }

  // Handle equipment item verification toggle
  const handleEquipmentVerification = (item: string) => {
    setEquipmentVerified(prev => ({
      ...prev,
      [item]: !prev[item]
    }));
  }

  // Handle status toggle
  const handleStatusToggle = (field: 'booked' | 'driver' | 'qualityControl' | 'whatsapp') => {
    // For quality control, only allow toggle if all equipment is verified
    if (field === 'qualityControl' && editedTask.qualityControl === 'No') {
      const allEquipmentVerified = editedTask.equipment.every(item => equipmentVerified[item]);
      if (!allEquipmentVerified) {
        alert('All equipment items must be verified before enabling Quality Control');
        return;
      }
    }
    
    setEditedTask(prev => ({
      ...prev,
      [field]: prev[field] === 'Yes' ? 'No' : 'Yes'
    }));
  }

  // Handle form submission
  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (onUpdate) {
      onUpdate(editedTask);
    }
    setIsModalOpen(false);
  }

  return (
    <>
      <li 
        ref={setNodeRef}
        style={{
          ...style,
          background: getProgressBackground(),
        }}
        {...attributes}
        {...listeners}
        className="bg-Surface p-3 rounded-md shadow cursor-grab active:cursor-grabbing border border-gray-200"
        onDoubleClick={handleDoubleClick}
      >
        <div className="flex justify-between items-start">
          <div className="flex flex-col space-y-1">
            <div className="flex items-center gap-2">
              <span className="bg-surface px-2 py-1 rounded-full text-text font-medium">{task.customer}</span>
              <span className="bg-surface px-2 py-1 rounded-full text-text text-sm">({task.company})</span>
            </div>
            <span className="bg-surface px-2 py-1 rounded-full text-text text-sm truncate max-w-xs">{task.address}</span>
            <div className="flex gap-1 flex-wrap mt-1">
              {task.equipment.map((item, index) => (
                <span key={index} className="text-xs bg-text text-base px-2 py-0.5 rounded-full">{item}</span>
              ))}
            </div>
          </div>
          <div className="flex flex-col items-end space-y-1">
            <span className={`text-xs text-base px-2 py-1 rounded-full ${getTypeBadgeColor()}`}>
              {task.type}
            </span>
            <div className="flex space-x-1 mt-1">
              <div className={`h-3 w-3 rounded-full ${task.booked === 'Yes' ? 'bg-green-500' : 'bg-red-500'}`} title="Booked" />
              <div className={`h-3 w-3 rounded-full ${task.driver === 'Yes' ? 'bg-green-500' : 'bg-red-500'}`} title="Driver" />
              <div className={`h-3 w-3 rounded-full ${task.qualityControl === 'Yes' ? 'bg-green-500' : 'bg-red-500'}`} title="Quality Control" />
              <div className={`h-3 w-3 rounded-full ${task.whatsapp === 'Yes' ? 'bg-green-500' : 'bg-red-500'}`} title="WhatsApp" />
            </div>
          </div>
        </div>
      </li>

      {/* Edit Modal - Now with higher z-index to ensure it's above all other elements */}
      {isModalOpen && (
        <div className="fixed inset-0 flex items-center justify-center z-[9999] bg-black/50">
          <div className="bg-white rounded-lg p-6 w-full max-w-lg shadow-xl" onClick={e => e.stopPropagation()}>
            <h2 className="text-xl text-base font-bold mb-4">Edit Task</h2>
            
            <form onSubmit={handleSubmit}>
              <div className="grid grid-cols-2 gap-4 mb-4">
                {/* Type Selection */}
                <div className="col-span-1">
                  <label className="block text-sm text-base font-medium mb-1">Type</label>
                  <select 
                    value={editedTask.type}
                    onChange={(e) => handleInputChange('type', e.target.value)}
                    className="w-full border border-gray-300 text-base rounded px-3 py-2"
                  >
                    <option value="Deliver">Deliver</option>
                    <option value="Collect">Collect</option>
                    <option value="Swap">Swap</option>
                  </select>
                </div>
                
                {/* Status Field */}
                <div className="col-span-1">
                  <label className="text-base block text-sm font-medium mb-1">Status</label>
                  <select 
                    value={editedTask.status}
                    onChange={(e) => handleInputChange('status', e.target.value)}
                    className="text-base w-full border border-gray-300 rounded px-3 py-2"
                  >
                    <option value="Backlog">Backlog</option>
                    <option value="Driver 1">Driver 1</option>
                    <option value="Driver 2">Driver 2</option>
                    <option value="Driver 3">Driver 3</option>
                    <option value="Driver 4">Driver 4</option>
                  </select>
                </div>
                
                {/* Customer */}
                <div className="col-span-1">
                  <label className="text-base block text-sm font-medium mb-1">Customer</label>
                  <input 
                    type="text" 
                    value={editedTask.customer}
                    onChange={(e) => handleInputChange('customer', e.target.value)}
                    className="text-base w-full border border-gray-300 rounded px-3 py-2"
                  />
                </div>
                
                {/* Company */}
                <div className="col-span-1">
                  <label className="text-base block text-sm font-medium mb-1">Company</label>
                  <input 
                    type="text" 
                    value={editedTask.company}
                    onChange={(e) => handleInputChange('company', e.target.value)}
                    className="text-base w-full border border-gray-300 rounded px-3 py-2"
                  />
                </div>
                
                {/* Address */}
                <div className="col-span-2">
                  <label className="text-base block text-sm font-medium mb-1">Address</label>
                  <input 
                    type="text" 
                    value={editedTask.address}
                    onChange={(e) => handleInputChange('address', e.target.value)}
                    className="text-base w-full border border-gray-300 rounded px-3 py-2"
                  />
                </div>
                
                {/* Equipment - now as an expandable list with checkboxes */}
                <div className="col-span-2">
                  <label className="text-base block text-sm font-medium mb-1">Equipment</label>
                  <div className="mb-2">
                    <input 
                      type="text" 
                      value={editedTask.equipment.join(', ')}
                      onChange={(e) => handleEquipmentChange(e.target.value)}
                      placeholder="Add equipment items separated by commas"
                      className="text-base w-full border border-gray-300 rounded px-3 py-2"
                    />
                  </div>
                  
                  {/* Equipment list with checkboxes */}
                  <div className="border border-gray-300 rounded max-h-40 overflow-y-auto p-2">
                    {editedTask.equipment.length === 0 ? (
                      <p className="text-base text-sm p-2">No equipment items added</p>
                    ) : (
                      <ul className="space-y-1">
                        {editedTask.equipment.map((item, index) => (
                          <li key={index} className="text-base flex items-center space-x-2 p-1 hover:bg-gray-100 rounded">
                            <input 
                              type="checkbox" 
                              id={`equipment-${index}`}
                              checked={equipmentVerified[item] || false}
                              onChange={() => handleEquipmentVerification(item)}
                              className="h-4 w-4"
                            />
                            <label htmlFor={`equipment-${index}`} className="flex-1 cursor-pointer">{item}</label>
                          </li>
                        ))}
                      </ul>
                    )}
                  </div>
                  <p className="text-xs text-gray-500 mt-1">All equipment must be verified before enabling Quality Control</p>
                </div>
                
                {/* Status Toggles - now red for No, green for Yes */}
                <div className="col-span-2 mt-2">
                  <label className="text-base block text-sm font-medium mb-2">Status Indicators</label>
                  <div className="flex flex-wrap gap-4">
                    <label className="text-base flex items-center space-x-2 cursor-pointer">
                      <div 
                        className={`w-6 h-6 rounded flex items-center justify-center text-white ${
                          editedTask.booked === 'Yes' ? 'bg-green' : 'bg-red'
                        }`}
                        onClick={() => handleStatusToggle('booked')}
                      >
                        {editedTask.booked === 'Yes' ? <span>✓</span> : <span>✕</span>}
                      </div>
                      <span>Booked</span>
                    </label>
                    
                    <label className="text-base flex items-center space-x-2 cursor-pointer">
                      <div 
                        className={`w-6 h-6 rounded flex items-center justify-center text-white ${
                          editedTask.driver === 'Yes' ? 'bg-green' : 'bg-red'
                        }`}
                        onClick={() => handleStatusToggle('driver')}
                      >
                        {editedTask.driver === 'Yes' ? <span>✓</span> : <span>✕</span>}
                      </div>
                      <span>Driver</span>
                    </label>
                    
                    <label className="text-base flex items-center space-x-2 cursor-pointer">
                      <div 
                        className={`w-6 h-6 rounded flex items-center justify-center text-white ${
                          editedTask.qualityControl === 'Yes' ? 'bg-green' : 'bg-red'
                        }`}
                        onClick={() => handleStatusToggle('qualityControl')}
                      >
                        {editedTask.qualityControl === 'Yes' ? <span>✓</span> : <span>✕</span>}
                      </div>
                      <span>Quality Control</span>
                    </label>
                    
                    <label className="text-base flex items-center space-x-2 cursor-pointer">
                      <div 
                        className={`w-6 h-6 rounded flex items-center justify-center text-white ${
                          editedTask.whatsapp === 'Yes' ? 'bg-green' : 'bg-red'
                        }`}
                        onClick={() => handleStatusToggle('whatsapp')}
                      >
                        {editedTask.whatsapp === 'Yes' ? <span>✓</span> : <span>✕</span>}
                      </div>
                      <span>WhatsApp</span>
                    </label>
                  </div>
                </div>
              </div>
              
              <div className="flex justify-end gap-2">
                <button
                  type="button"
                  onClick={() => setIsModalOpen(false)}
                  className="px-4 py-2 bg-red text-base rounded hover:bg-gray-200"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  className="px-4 py-2 bg-green text-base rounded hover:bg-blue-600"
                >
                  Save Changes
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </>
  )
}