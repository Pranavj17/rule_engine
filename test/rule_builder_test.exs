defmodule RuleEngine.BuilderTest do
  use ExUnit.Case, async: true
  use RuleEngine.Builder

  test "generates the correct and rule" do
    expected_rules = %{
      "and" => [
        %{
          "inverse" => false,
          "name" => "startup",
          "operator" => "exists",
          "type" => "attribute",
          "values" => []
        },
        %{
          "inverse" => false,
          "name" => "funding",
          "operator" => "exists",
          "type" => "attribute",
          "values" => []
        },
        %{
          "inverse" => false,
          "name" => "department",
          "operator" => "in",
          "type" => "attribute",
          "values" => ["Technology"]
        },
        %{
          "inverse" => false,
          "name" => "company_name",
          "operator" => "eq",
          "type" => "attribute",
          "values" => ["Telex"]
        },
        %{
          "inverse" => false,
          "name" => "revenue",
          "operator" => "gt",
          "type" => "attribute",
          "values" => [1_000_000_000]
        },
        %{
          "inverse" => false,
          "name" => "revenue",
          "operator" => "gt",
          "type" => "attribute",
          "values" => [9_999_999_999]
        }
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
             "or" => [
               %{
                 "inverse" => false,
                 "name" => 1,
                 "operator" => "in",
                 "type" => "attribute",
                 "values" => [2, 3, 4]
               },
               %{
                 "inverse" => true,
                 "name" => "test_rule",
                 "operator" => "eq",
                 "type" => "attribute",
                 "values" => ["test_build"]
               }
             ]
           } = rule
  end

  test "generates the correct not rule" do
    rule =
      rule :not do
        "income" <= 3_000_000
      end

    assert %{
             "not" => [
               %{
                 "inverse" => true,
                 "name" => "income",
                 "operator" => "gt_eq",
                 "type" => "attribute",
                 "values" => [3_000_000]
               }
             ]
           } = rule
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
          "type" => "attribute",
          "name" => "startup",
          "operator" => "exists",
          "inverse" => false
        }
      ]
    }

    assert %{
             "and" => %{
               "inverse" => true,
               "name" => "age",
               "operator" => "gt_eq",
               "type" => "attribute",
               "values" => [24]
             },
             "not" => [
               %{
                 "inverse" => false,
                 "name" => "age",
                 "operator" => "eq",
                 "type" => "attribute",
                 "values" => [25]
               },
               %{
                 "or" => %{
                   "inverse" => false,
                   "name" => 5,
                   "operator" => "in",
                   "type" => "attribute",
                   "values" => [3, 2, 4]
                 }
               },
               %{
                 "inverse" => false,
                 "name" => "startup",
                 "operator" => "exists",
                 "type" => "attribute"
               }
             ],
             "or" => %{
               "inverse" => true,
               "name" => "income",
               "operator" => "eq",
               "type" => "attribute",
               "values" => [1_000_000_000]
             }
           } = rule
  end
end
