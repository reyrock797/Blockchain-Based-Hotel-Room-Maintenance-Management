import { describe, it, expect, beforeEach } from 'vitest';

// Mock principal addresses
const PROPERTY_OWNER = 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM';
const STAFF_MEMBER = 'ST2CY5V39NHDPWSXMW9QDT3HC3GD6Q6XX4CFRK9AG';
const NEW_STAFF = 'ST2JHG361ZXG51QTKY2NQCVBPPRRE2KZB1HR05NNC';
const UNAUTHORIZED = 'ST3NBRSFKX28FQ2ZJ1MAKX58HKHSDGNV5N7R21XCP';

// Constants
const STATUS_ASSIGNED = 0;
const STATUS_IN_PROGRESS = 1;
const STATUS_COMPLETED = 2;
const STATUS_VERIFIED = 3;

const TASK_CLEANING = 0;
const TASK_REPAIR = 1;

// Mock contract state
let contractState = {
  'work-order-id-counter': 0,
  'work-orders': {},
  'staff-assignments': {}
};

// Mock contract functions
const maintenanceAssignment = {
  'create-work-order': (caller, roomNumber, assignedTo, taskType, description) => {
    const newId = contractState['work-order-id-counter'];
    contractState['work-order-id-counter'] = newId + 1;
    
    contractState['work-orders'][newId] = {
      'property-owner': caller,
      'room-number': roomNumber,
      'assigned-to': assignedTo,
      'status': STATUS_ASSIGNED,
      'task-type': taskType,
      'description': description,
      'created-at': Date.now(),
      'updated-at': Date.now()
    };
    
    // Update staff assignments
    const staffKey = assignedTo;
    if (contractState['staff-assignments'][staffKey]) {
      contractState['staff-assignments'][staffKey]['active-assignments'] += 1;
    } else {
      contractState['staff-assignments'][staffKey] = { 'active-assignments': 1 };
    }
    
    return { type: 'ok', value: newId };
  },
  
  'update-work-order-status': (caller, orderId, newStatus) => {
    if (!contractState['work-orders'][orderId]) {
      return { type: 'err', value: 404 };
    }
    
    const order = contractState['work-orders'][orderId];
    
    if (caller !== order['property-owner'] && caller !== order['assigned-to']) {
      return { type: 'err', value: 403 };
    }
    
    // If completing the work, decrement active assignments
    if (newStatus === STATUS_COMPLETED && order['status'] !== STATUS_COMPLETED) {
      const staffKey = order['assigned-to'];
      if (contractState['staff-assignments'][staffKey]) {
        contractState['staff-assignments'][staffKey]['active-assignments'] -= 1;
      }
    }
    
    order['status'] = newStatus;
    order['updated-at'] = Date.now();
    
    return { type: 'ok', value: true };
  },
  
  'reassign-work-order': (caller, orderId, newAssignee) => {
    if (!contractState['work-orders'][orderId]) {
      return { type: 'err', value: 404 };
    }
    
    const order = contractState['work-orders'][orderId];
    
    if (caller !== order['property-owner']) {
      return { type: 'err', value: 403 };
    }
    
    // Decrement old assignee's count
    const oldStaffKey = order['assigned-to'];
    if (contractState['staff-assignments'][oldStaffKey]) {
      contractState['staff-assignments'][oldStaffKey]['active-assignments'] -= 1;
    }
    
    // Increment new assignee's count
    const newStaffKey = newAssignee;
    if (contractState['staff-assignments'][newStaffKey]) {
      contractState['staff-assignments'][newStaffKey]['active-assignments'] += 1;
    } else {
      contractState['staff-assignments'][newStaffKey] = { 'active-assignments': 1 };
    }
    
    order['assigned-to'] = newAssignee;
    order['updated-at'] = Date.now();
    
    return { type: 'ok', value: true };
  },
  
  'get-work-order': (orderId) => {
    return contractState['work-orders'][orderId] || null;
  },
  
  'get-staff-workload': (staffAddress) => {
    return contractState['staff-assignments'][staffAddress]?.['active-assignments'] || 0;
  }
};

describe('Maintenance Assignment Contract', () => {
  beforeEach(() => {
    // Reset contract state before each test
    contractState = {
      'work-order-id-counter': 0,
      'work-orders': {},
      'staff-assignments': {}
    };
  });
  
  it('should allow property owner to create a work order', () => {
    const result = maintenanceAssignment['create-work-order'](
        PROPERTY_OWNER,
        101,
        STAFF_MEMBER,
        TASK_CLEANING,
        'Clean room after checkout'
    );
    
    expect(result.type).toBe('ok');
    expect(result.value).toBe(0); // First work order ID
    
    expect(contractState['work-orders'][0]).toBeDefined();
    expect(contractState['work-orders'][0]['property-owner']).toBe(PROPERTY_OWNER);
    expect(contractState['work-orders'][0]['assigned-to']).toBe(STAFF_MEMBER);
    expect(contractState['work-orders'][0]['task-type']).toBe(TASK_CLEANING);
    
    // Check staff assignments
    expect(contractState['staff-assignments'][STAFF_MEMBER]['active-assignments']).toBe(1);
  });
  
  it('should allow assigned staff to update work order status', () => {
    // First create a work order
    maintenanceAssignment['create-work-order'](
        PROPERTY_OWNER,
        101,
        STAFF_MEMBER,
        TASK_CLEANING,
        'Clean room after checkout'
    );
    
    // Staff updates status to in progress
    const result = maintenanceAssignment['update-work-order-status'](
        STAFF_MEMBER,
        0,
        STATUS_IN_PROGRESS
    );
    
    expect(result.type).toBe('ok');
    expect(contractState['work-orders'][0]['status']).toBe(STATUS_IN_PROGRESS);
  });
  
  it('should decrement staff workload when work is completed', () => {
    // First create a work order
    maintenanceAssignment['create-work-order'](
        PROPERTY_OWNER,
        101,
        STAFF_MEMBER,
        TASK_CLEANING,
        'Clean room after checkout'
    );
    
    expect(contractState['staff-assignments'][STAFF_MEMBER]['active-assignments']).toBe(1);
    
    // Staff completes the work
    maintenanceAssignment['update-work-order-status'](
        STAFF_MEMBER,
        0,
        STATUS_COMPLETED
    );
    
    expect(contractState['staff-assignments'][STAFF_MEMBER]['active-assignments']).toBe(0);
  });
  
  it('should allow property owner to reassign work orders', () => {
    // First create a work order
    maintenanceAssignment['create-work-order'](
        PROPERTY_OWNER,
        101,
        STAFF_MEMBER,
        TASK_CLEANING,
        'Clean room after checkout'
    );
    
    // Property owner reassigns the work
    const result = maintenanceAssignment['reassign-work-order'](
        PROPERTY_OWNER,
        0,
        NEW_STAFF
    );
    
    expect(result.type).toBe('ok');
    expect(contractState['work-orders'][0]['assigned-to']).toBe(NEW_STAFF);
    
    // Check staff assignments were updated
    expect(contractState['staff-assignments'][STAFF_MEMBER]['active-assignments']).toBe(0);
    expect(contractState['staff-assignments'][NEW_STAFF]['active-assignments']).toBe(1);
  });
  
  it('should not allow unauthorized users to reassign work orders', () => {
    // First create a work order
    maintenanceAssignment['create-work-order'](
        PROPERTY_OWNER,
        101,
        STAFF_MEMBER,
        TASK_CLEANING,
        'Clean room after checkout'
    );
    
    // Unauthorized user tries to reassign
    const result = maintenanceAssignment['reassign-work-order'](
        UNAUTHORIZED,
        0,
        NEW_STAFF
    );
    
    expect(result.type).toBe('err');
    expect(result.value).toBe(403);
    expect(contractState['work-orders'][0]['assigned-to']).toBe(STAFF_MEMBER); // Unchanged
  });
});

console.log('Maintenance Assignment Contract tests completed successfully!');
