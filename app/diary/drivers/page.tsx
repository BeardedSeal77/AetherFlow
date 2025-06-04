'use client'

import { useState, useEffect } from 'react'
import { useRouter } from 'next/navigation'
import { 
  DndContext, 
  useSensors, 
  useSensor, 
  PointerSensor, 
  KeyboardSensor,
  closestCorners,
  DragEndEvent,
  DragStartEvent,
  DragOverEvent,
  DragOverlay,
  useDroppable
} from '@dnd-kit/core'
import { 
  SortableContext, 
  sortableKeyboardCoordinates,
  verticalListSortingStrategy
} from '@dnd-kit/sortable'

import DriverItem from '@/components/DriverItem'

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

// Create a droppable container component
function DroppableContainer({ id, children }: { id: string, children: React.ReactNode }) {
  const { setNodeRef } = useDroppable({
    id: id
  });
  
  return (
    <div ref={setNodeRef} className="h-full">
      {children}
    </div>
  );
}

export default function Drivers() {
  const router = useRouter()
  const [tasks, setTasks] = useState<DriverTask[]>([])
  const [isLoading, setIsLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [activeId, setActiveId] = useState<string | null>(null)
  const [activeTask, setActiveTask] = useState<DriverTask | null>(null)

  // Configure sensors for drag and drop
  const sensors = useSensors(
    useSensor(PointerSensor, {
      activationConstraint: {
        distance: 8,
      },
    }),
    useSensor(KeyboardSensor, {
      coordinateGetter: sortableKeyboardCoordinates,
    })
  )

  // Our statuses now include backlog and the 4 drivers
  const statuses = ['Backlog', 'Driver 1', 'Driver 2', 'Driver 3', 'Driver 4']

  useEffect(() => {
    // Check if user is logged in
    fetch('/api/auth/session')
      .then(res => {
        // Check if response is OK before parsing JSON
        if (!res.ok) {
          throw new Error(`Auth session error: ${res.status} ${res.statusText}`);
        }
        return res.text(); // First get as text to check if it's valid JSON
      })
      .then(text => {
        try {
          // Try to parse the text as JSON
          if (!text || text.trim() === '') {
            return { user: null }; // Handle empty response
          }
          return JSON.parse(text);
        } catch (err) {
          console.error('Failed to parse auth session response:', text.substring(0, 100));
          throw new Error('Invalid JSON in auth session response');
        }
      })
      .then(data => {
        if (!data.user) {
          router.push('/login')
          return null;
        }
        
        // Fetch driver tasks
        return fetch('/api/diary/drivers')
          .then(res => {
            if (!res.ok) {
              throw new Error(`Drivers API error: ${res.status} ${res.statusText}`);
            }
            return res.text(); // Get as text first
          })
          .then(text => {
            try {
              // Try to parse the text as JSON
              if (!text || text.trim() === '') {
                return { tasks: [] }; // Handle empty response
              }
              return JSON.parse(text);
            } catch (err) {
              console.error('Failed to parse drivers API response:', text.substring(0, 100));
              throw new Error('Invalid JSON in drivers API response');
            }
          });
      })
      .then(data => {
        if (data) {
          // Convert the existing task format to the new format
          const convertedTasks = (data.tasks || []).map((task: any) => ({
            id: task.id,
            status: task.status,
            type: task.type || 'Deliver', // Default to 'Deliver' if not specified
            equipment: task.equipment ? 
              (Array.isArray(task.equipment) ? task.equipment : task.equipment.split(',').map((s: string) => s.trim())) : 
              [],
            customer: task.customer || "Customer Name",
            company: task.company || "Company Name",
            address: task.address || "Address",
            booked: task.booked || 'No',
            driver: task.driver || 'No',
            qualityControl: task.qualityControl || 'No',
            whatsapp: task.whatsapp || 'No',
          }));
          
          setTasks(convertedTasks);
        }
        setIsLoading(false);
      })
      .catch(err => {
        console.error('Failed to fetch data:', err)
        setError(err.message)
        setIsLoading(false)
      })
  }, [router])

  function handleDragStart(event: DragStartEvent) {
    const { active } = event
    setActiveId(active.id as string)
    
    // Find the active task to display in the DragOverlay
    const draggedTask = tasks.find(task => task.id === active.id)
    if (draggedTask) {
      setActiveTask(draggedTask)
    }
  }

  function handleDragOver(event: DragOverEvent) {
    // Not needed for this implementation
  }

  function handleDragEnd(event: DragEndEvent) {
    const { active, over } = event
    
    if (!over) {
      setActiveId(null)
      setActiveTask(null)
      return
    }
    
    // Find the active task
    const activeTaskId = active.id as string;
    const taskToUpdate = tasks.find(task => task.id === activeTaskId);
    
    if (!taskToUpdate) {
      setActiveId(null)
      setActiveTask(null)
      return
    }
    
    let newStatus: string;
    
    // Check if we're dropping over a container or a task
    if (statuses.includes(over.id as string)) {
      // Dropping directly into a container
      newStatus = over.id as string;
    } else {
      // Dropping over another task - find its container
      const overTask = tasks.find(task => task.id === over.id);
      if (!overTask) {
        setActiveId(null)
        setActiveTask(null)
        return;
      }
      
      newStatus = overTask.status;
    }
    
    // Don't update if the status didn't change
    if (taskToUpdate.status === newStatus) {
      setActiveId(null)
      setActiveTask(null)
      return;
    }
    
    // Create a copy of the task with the updated status
    const updatedTask: DriverTask = {
      ...taskToUpdate,
      status: newStatus,
      driver: newStatus.startsWith('Driver') ? 'Yes' : 'No'
    };
    
    // Update task status
    setTasks(prevTasks => 
      prevTasks.map(task => {
        if (task.id === activeTaskId) {
          return updatedTask;
        }
        return task;
      })
    );
    
    // Send update to backend
    fetch(`/api/diary/drivers/${activeTaskId}`, {
      method: 'PUT',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(updatedTask),
    })
    .then(res => {
      if (!res.ok) {
        console.error(`Task update error: Status ${res.status}`);
        // Show error but don't throw to prevent UI disruption
        setError(`Failed to update task: ${res.statusText}`);
        // Revert the change locally if the API fails
        setTasks(prevTasks => 
          prevTasks.map(task => {
            if (task.id === activeTaskId) {
              return taskToUpdate; // Revert to original
            }
            return task;
          })
        );
      }
      return res.text();
    })
    .then(text => {
      // Only try to parse as JSON if there's content
      if (text && text.trim() !== '') {
        try {
          return JSON.parse(text);
        } catch (err) {
          console.error('Failed to parse task update response:', text.substring(0, 100));
        }
      }
      // Clear any previous errors on success
      setError(null);
    })
    .catch(err => {
      console.error('Failed to update task status:', err);
      setError(`Network error: ${err.message}`);
      // Revert the change locally if the API fails
      setTasks(prevTasks => 
        prevTasks.map(task => {
          if (task.id === activeTaskId) {
            return taskToUpdate; // Revert to original
          }
          return task;
        })
      );
    });
    
    setActiveId(null);
    setActiveTask(null);
  }

  // Handle task update from DriverItem edit modal
  const handleTaskUpdate = (updatedTask: DriverTask) => {
    // Update local state
    setTasks(prevTasks => 
      prevTasks.map(task => {
        if (task.id === updatedTask.id) {
          return updatedTask;
        }
        return task;
      })
    );
    
    // Send update to backend
    fetch(`/api/diary/drivers/${updatedTask.id}`, {
      method: 'PUT',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(updatedTask),
    })
    .then(res => {
      if (!res.ok) {
        console.error(`Task update error: Status ${res.status}`);
        setError(`Failed to update task: ${res.statusText}`);
        // Revert the change if API fails
        setTasks(prevTasks => 
          prevTasks.map(task => {
            if (task.id === updatedTask.id) {
              // Find the original task
              const originalTask = prevTasks.find(t => t.id === updatedTask.id);
              return originalTask || task;
            }
            return task;
          })
        );
      }
      return res.text();
    })
    .then(text => {
      if (text && text.trim() !== '') {
        try {
          return JSON.parse(text);
        } catch (err) {
          console.error('Failed to parse task update response:', text.substring(0, 100));
        }
      }
      setError(null);
    })
    .catch(err => {
      console.error('Failed to update task:', err);
      setError(`Network error: ${err.message}`);
    });
  }

  if (isLoading) {
    return (
      <div className="flex justify-center items-center h-64">
        <div className="animate-spin rounded-full h-10 w-10 border-t-2 border-b-2 border-Rose"></div>
      </div>
    )
  }

  if (error) {
    return (
      <div className="flex justify-center items-center h-64">
        <div className="bg-red-100 border border-red-400 text-red-700 px-4 py-3 rounded relative" role="alert">
          <strong className="font-bold">Error:</strong>
          <span className="block sm:inline"> {error}</span>
        </div>
      </div>
    )
  }

  return (
    <DndContext
      sensors={sensors}
      collisionDetection={closestCorners}
      onDragStart={handleDragStart}
      onDragOver={handleDragOver}
      onDragEnd={handleDragEnd}
    >
      <div className="flex flex-col md:flex-row gap-8">
        {/* Backlog column - takes full left column */}
        <div className="w-full md:w-[450px] flex-shrink-0">
          <DroppableContainer id="Backlog">
            <div className="bg-red/70 backdrop-blur-md border border-text/20 rounded-lg p-4 shadow-inner h-full min-w-[400px]">
              <h3 className="text-lg font-semibold text-text mb-2">Backlog</h3>
              <SortableContext 
                items={tasks.filter(task => task.status === 'Backlog').map(task => task.id)} 
                strategy={verticalListSortingStrategy}
              >
                <ul className="space-y-3 min-h-[60px]">
                  {tasks.filter(task => task.status === 'Backlog').length === 0 && (
                    <li className="p-3 border border-dashed border-gray-400 text-center text-sm text-gray-400">
                      Drop here
                    </li>
                  )}
                  {tasks.filter(task => task.status === 'Backlog').map((task) => (
                    <DriverItem key={task.id} task={task} onUpdate={handleTaskUpdate} />
                  ))}
                </ul>
              </SortableContext>
            </div>
          </DroppableContainer>
        </div>

        {/* Drivers section - will wrap as needed */}
        <div className="flex-1 min-w-0">
          <div className="flex flex-wrap gap-4">
            {statuses.slice(1).map((status) => (
              <div key={status} className="min-w-[400px] flex-1">
                <DroppableContainer id={status}>
                  <div className="bg-blue/70 backdrop-blur-md border border-text/20 rounded-lg p-4 shadow-inner h-full">
                    <h3 className="text-lg font-semibold text-text mb-2">{status}</h3>
                    <SortableContext 
                      items={tasks.filter(task => task.status === status).map(task => task.id)} 
                      strategy={verticalListSortingStrategy}
                    >
                      <ul className="space-y-3 min-h-[60px]">
                        {tasks.filter(task => task.status === status).length === 0 && (
                          <li className="p-3 border border-dashed border-gray-400 text-center text-sm text-gray-400">
                            Drop here
                          </li>
                        )}
                        {tasks.filter(task => task.status === status).map((task) => (
                          <DriverItem key={task.id} task={task} onUpdate={handleTaskUpdate} />
                        ))}
                      </ul>
                    </SortableContext>
                  </div>
                </DroppableContainer>
              </div>
            ))}
          </div>
        </div>
      </div>
      
      {/* DragOverlay component for showing the dragged item */}
      <DragOverlay>
        {activeId && activeTask ? (
          <div className="bg-Surface p-3 rounded-md shadow">
            <div className="flex justify-between items-center">
              <span>{activeTask.customer} - {activeTask.company}</span>
              <div className="h-4 w-4 rounded-full bg-Highlight/50 flex-shrink-0" />
            </div>
          </div>
        ) : null}
      </DragOverlay>
    </DndContext>
  );
}