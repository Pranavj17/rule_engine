defmodule RuleEngine.Operators do
  import Constant

  Enum.each(
    [
      {:exists, "exists"},
      {:equal_to, "eq"},
      {:greater_than, "gt"},
      {:in_operator, "in"},
      {:timestamp_before, "timestamp_before"},
      {:field_type, "type"},
      {:name, "name"},
      {:operator, "operator"},
      {:inverse, "inverse"},
      {:values, "values"},
      {:attribute, "attribute"},
      {:predefined, "predefined"}
    ],
    fn {key, value} -> defconst(key, value) end
  )
end
