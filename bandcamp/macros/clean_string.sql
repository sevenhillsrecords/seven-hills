{% macro clean_string(column_name) %}
    {#
        -- ====================================================================
        -- Macro: clean_string
        -- Description: Standardizes messy text columns by gracefully converting 
        --              Python/CSV artifacts ('nan', 'None'), true empty strings, 
        --              and invisible whitespace/ghost spaces into proper SQL NULLs.
        
        -- Arguments:
        --     - column_name: The raw column identifier to be cleaned and cast.
            
        -- Example Usage:
        --     {{ clean_string('ship_to_name') }} AS ship_to_name
        -- ====================================================================
    #}
    CASE 
        WHEN {{ column_name }} IS NULL 
          OR CAST({{ column_name }} AS VARCHAR) IN ('nan', 'None', '') 
          OR trim(CAST({{ column_name }} AS VARCHAR)) = '' 
          OR regexp_replace(CAST({{ column_name }} AS VARCHAR), '^\s*$', '') = '' 
        THEN NULL 
        ELSE CAST({{ column_name }} AS VARCHAR) 
    END
{% endmacro %}