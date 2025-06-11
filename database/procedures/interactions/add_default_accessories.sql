-- =============================================================================
-- INTERACTIONS: Add default accessories for equipment
-- =============================================================================
-- Purpose: Automatically add default accessories for equipment in an interaction
-- Dependencies: interactions.component_equipment_list, core.equipment_accessories
-- Used by: Hire creation when no accessories specified
-- Function: interactions.add_default_accessories
-- Created: 2025-06-11
-- =============================================================================

SET search_path TO core, interactions, tasks, security, system, public;

-- Drop existing function if it exists
DROP FUNCTION IF EXISTS interactions.add_default_accessories;

-- =============================================================================
-- FUNCTION IMPLEMENTATION
-- =============================================================================

CREATE OR REPLACE FUNCTION interactions.add_default_accessories(p_interaction_id INTEGER)
RETURNS TABLE(
    success BOOLEAN,
    message TEXT,
    equipment_processed INTEGER,
    accessories_added_count INTEGER,
    total_accessories_cost DECIMAL(10,2)
) AS $$
DECLARE
    v_equipment_record RECORD;
    v_equipment_count INTEGER := 0;
    v_accessories_count INTEGER := 0;
    v_total_cost DECIMAL(10,2) := 0.00;
    v_equipment_accessories_cost DECIMAL(10,2);
    v_interaction_exists BOOLEAN;
BEGIN
    -- Validate interaction exists
    SELECT EXISTS(SELECT 1 FROM interactions.interactions WHERE id = p_interaction_id)
    INTO v_interaction_exists;
    
    IF NOT v_interaction_exists THEN
        RETURN QUERY SELECT 
            false,
            'Interaction not found.'::TEXT,
            0,
            0,
            0.00::DECIMAL(10,2);
        RETURN;
    END IF;
    
    -- Process each equipment item in the interaction
    FOR v_equipment_record IN 
        SELECT cel.equipment_category_id, cel.quantity as equipment_quantity
        FROM interactions.component_equipment_list cel
        WHERE cel.interaction_id = p_interaction_id
    LOOP
        v_equipment_count := v_equipment_count + 1;
        
        -- Add default accessories for this equipment category
        INSERT INTO interactions.component_accessories_list (
            interaction_id,
            accessory_id,
            quantity,
            is_default_selection,
            unit_cost_at_time,
            notes,
            created_at
        )
        SELECT 
            p_interaction_id,
            ea.id,
            (ea.quantity * v_equipment_record.equipment_quantity), -- Multiply by equipment quantity
            true, -- This is a default selection
            ea.unit_cost,
            'Default accessory for ' || ec.category_name,
            CURRENT_TIMESTAMP
        FROM core.equipment_accessories ea
        JOIN core.equipment_categories ec ON ea.equipment_category_id = ec.id
        WHERE ea.equipment_category_id = v_equipment_record.equipment_category_id
          AND ea.accessory_type = 'default'
          AND ea.is_active = true;
        
        -- Count accessories added and calculate cost for this equipment
        SELECT 
            COUNT(*),
            COALESCE(SUM(ea.unit_cost * ea.quantity * v_equipment_record.equipment_quantity), 0)
        INTO v_accessories_count, v_equipment_accessories_cost
        FROM core.equipment_accessories ea
        WHERE ea.equipment_category_id = v_equipment_record.equipment_category_id
          AND ea.accessory_type = 'default'
          AND ea.is_active = true;
        
        v_total_cost := v_total_cost + v_equipment_accessories_cost;
    END LOOP;
    
    -- Get final count of accessories added
    SELECT COUNT(*) INTO v_accessories_count
    FROM interactions.component_accessories_list
    WHERE interaction_id = p_interaction_id
      AND is_default_selection = true;
    
    -- Return success
    RETURN QUERY SELECT 
        true,
        ('Default accessories added for ' || v_equipment_count || ' equipment items. ' || 
         v_accessories_count || ' accessories total.')::TEXT,
        v_equipment_count,
        v_accessories_count,
        v_total_cost;
        
EXCEPTION 
    WHEN OTHERS THEN
        RETURN QUERY SELECT 
            false, 
            ('Error adding default accessories: ' || SQLERRM)::TEXT,
            0,
            0,
            0.00::DECIMAL(10,2);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================================================
-- PERMISSIONS & COMMENTS
-- =============================================================================

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION interactions.add_default_accessories TO PUBLIC;

-- Add function documentation
COMMENT ON FUNCTION interactions.add_default_accessories IS 
'Automatically add default accessories for all equipment in an interaction.
Reads equipment from component_equipment_list and adds corresponding default accessories.
Used when hire is created without specific accessory selections.';

-- =============================================================================
-- USAGE EXAMPLES
-- =============================================================================

/*
-- Example usage:
-- Add default accessories for all equipment in interaction 1001
SELECT * FROM interactions.add_default_accessories(1001);

-- Typical workflow:
-- 1. Create interaction and equipment list
-- 2. Call this function to add defaults
-- 3. Optionally call add_interaction_accessories() to add custom selections
*/