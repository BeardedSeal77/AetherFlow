'use client'

interface Task {
  id: string;
  title: string;
  status: string;
}

interface TaskBoardProps {
  tasks: Task[];
}

export default function TaskBoard({ tasks }: TaskBoardProps) {
  const statuses = ['Backlog', 'In Progress', 'In Review', 'Completed'];

  return (
    <div className="grid grid-cols-4 gap-4">
      {statuses.map((status) => (
        <div
          key={status}
          className="bg-Overlay/30 backdrop-blur-md border border-Highlight/20 rounded-lg p-4 shadow-inner"
        >
          <h3 className="text-lg font-semibold text-Highlight mb-2">{status}</h3>
          <ul className="space-y-3">
            {tasks
              .filter((task) => task.status === status)
              .map((task) => (
                <li key={task.id} className="bg-Surface p-3 rounded-md shadow">
                  {task.title}
                </li>
              ))}
          </ul>
        </div>
      ))}
    </div>
  );
}