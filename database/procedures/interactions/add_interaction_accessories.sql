-- =============================================================================
-- INTERACTIONS: Add accessories to interaction
-- =============================================================================
-- Purpose: Add accessories to an existing interaction
-- Dependencies: interactions.component_accessories_list, core.equipment_accessories
-- Used by: Hire creation, off-hire creation, breakdown creation
-- Function: interactions.add_interaction_accessories
-- Created: 2025-06-11
-- =============================================================================

SET search_path TO core, interactions, tasks, security, system, public;

-- Drop existing function if it exists
DROP FUNCTION IF EXISTS interactions.add_interaction_accessories;

-- =============================================================================
-- FUNCTION IMPLEMENTATION
-- =============================================================================

CREATE OR REPLACE FUNCTION interactions.add_interaction_accessories(
    p_interaction_id INTEGER,
    p_accessories_list JSONB -- [{"accessory_id": 1, "quantity": 1, "is_default": true, "notes": "..."}]
)
RETURNS TABLE(
    success BOOLEAN,
    message TEXT,
    accessories_added_count INTEGER,
    total_accessories_cost DECIMAL(10,2)
) AS $$
DECLARE
    v_accessory_item JSONB;
    v_accessories_count INTEGER := 0;
    v_total_cost DECIMAL(10,2) := 0.00;
    v_accessory_cost DECIMAL(8,2);
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
            0.00::DECIMAL(10,2);
        RETURN;
    END IF;
    
    -- Validate accessories list
    IF p_accessories_list IS NULL OR jsonb_array_length(p_accessories_list) = 0 THEN
        RETURN QUERY SELECT 
            true,
            'No accessories to add.'::TEXT,
            0,
            0.00::DECIMAL(10,2);
        RETURN;
    END IF;
    
    -- Process each accessory
    FOR v_accessory_item IN SELECT * FROM jsonb_array_elements(p_accessories_list)
    LOOP
        -- Get current cost for this accessory
        SELECT unit_cost INTO v_accessory_cost
        FROM core.equipment_accessories
        WHERE id = (v_accessory_item->>'accessory_id')::INTEGER
          AND is_active = true;
        
        -- Skip if accessory not found or inactive
        IF v_accessory_cost IS NULL THEN
            CONTINUE;
        END IF;
        
        -- Insert accessory record
        INSERT INTO interactions.component_accessories_list (
            interaction_id,
            accessory_id,
            quantity,
            is_default_selection,
            unit_cost_at_time,
            notes,
            created_at
        ) VALUES (
            p_interaction_id,
            (v_accessory_item->>'accessory_id')::INTEGER,
            COALESCE((v_accessory_item->>'quantity')::INTEGER, 1),
            COALESCE((v_accessory_item->>'is_default')::BOOLEAN, false),
            v_accessory_cost,
            v_accessory_item->>'notes',
            CURRENT_TIMESTAMP
        );
        
        v_accessories_count := v_accessories_count + 1;
        v_total_cost := v_total_cost + (v_accessory_cost * COALESCE((v_accessory_item->>'quantity')::INTEGER, 1));
    END LOOP;
    
    -- Return success
    RETURN QUERY SELECT 
        true,
        (v_accessories_count || ' accessories added successfully.')::TEXT,
        v_accessories_count,
        v_total_cost;
        
EXCEPTION 
    WHEN foreign_key_violation THEN
        RETURN QUERY SELECT 
            false, 
            'Invalid accessory ID in accessories list.'::TEXT,
            0,
            0.00::DECIMAL(10,2);
            
    WHEN OTHERS THEN
        RETURN QUERY SELECT 
            false, 
            ('Error adding accessories: ' || SQLERRM)::TEXT,
            0,
            0.00::DECIMAL(10,2);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================================================
-- PERMISSIONS & COMMENTS
-- =============================================================================

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION interactions.add_interaction_accessories TO PUBLIC;

-- Add function documentation
COMMENT ON FUNCTION interactions.add_interaction_accessories IS 
'Add accessories to an existing interaction.
Processes JSONB array of accessory selections and records them with current pricing.
Used by hire, off-hire, and breakdown creation procedures.';

-- =============================================================================
-- USAGE EXAMPLES
-- =============================================================================

/*
-- Example usage:
-- Add accessories to interaction
SELECT * FROM interactions.add_interaction_accessories(
    1001,
    '[
        {"accessory_id": 1, "quantity": 1, "is_default": true},
        {"accessory_id": 4, "quantity": 2, "is_default": false, "notes": "Extra fuel requested"}
    ]'::jsonb
);

-- Add single accessory
SELECT * FROM interactions.add_interaction_accessories(
    1001,
    '[{"accessory_id": 5, "quantity": 1}]'::jsonb
);
*/