defmodule RuleEngine.BuilderTest do
  use ExUnit.Case, async: true
  use RuleEngine.Builder

  test "generates the correct and rule" do
    expected_rules = %{
      and: [
        %{name: "startup", values: [], operator: "exists"},
        %{name: "funding", values: [], operator: "exists"},
        %{name: "department", values: ["Technology"], operator: "in"},
        %{name: "company_name", values: ["Telex"], operator: "eq"},
        %{name: "revenue", values: [1_000_000_000], operator: "gt"},
        %{name: "revenue", values: [9_999_999_999], operator: "gt"}
      ]
    }

    assert ^expected_rules =
             rule(:and,
               do: [
                 exists?("startup"),
                 exists?("funding"),
                 "department" in "Technology",
                 "company_name" == "Telex",
                 "revenue" > 1_000_000_000,
                 "revenue" > 9_999_999_999
               ]
             )
  end

  test "generates the correct or rule" do
    rule =
      rule :or do
        [
          1 in [2, 3, 4],
          "test_rule" != "test_build"
        ]
      end

    assert %{
             or: [
               %{name: 1, values: [2, 3, 4], operator: "in"},
               %{name: "test_rule", values: ["test_build"], operator: "eq"}
             ]
           } = rule
  end

  test "generates the correct not rule" do
    rule =
      rule :not do
        "income" <= 3_000_000
      end

    assert %{not: [%{name: "income", values: [3_000_000], operator: "gte"}]} = rule
  end

  test "generates the correct combination of rules" do
    rule = %{
      "and" => "age" <= 24,
      "or" => "income" != 1_000_000_000,
      "not" => [
        "age" == 25,
        %{
          "or" => 5 in [3, 2, 4]
        },
        %{
          "name" => "startup",
          "operator" => "exists"
        }
      ]
    }

    assert %{
             "and" => %{name: "age", values: [24], operator: "gte"},
             "not" => [
               %{name: "age", values: [25], operator: "eq"},
               %{"or" => %{name: 5, values: [3, 2, 4], operator: "in"}},
               %{"name" => "startup", "operator" => "exists"}
             ],
             "or" => %{name: "income", values: [1_000_000_000], operator: "eq"}
           } = rule
  end
end
