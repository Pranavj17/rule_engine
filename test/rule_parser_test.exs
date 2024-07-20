defmodule RuleEngine.RuleParserTest do
  alias ElixirLS.LanguageServer.Providers.CodeLens.Test
  use ExUnit.Case, async: true
  use RuleEngine.Builder

  defmodule TestRuleParser do
    use RuleEngine.Parser,
      adapter: RuleEngine.Adapters.Elasticsearch

    use RuleEngine.Builder

    def whitelisted_attributes do
      %{
        "startup" => "startup",
        "funding" => "funding",
        "department" => "department",
        "company_name" => "company_name",
        "revenue" => "revenue"
      }
    end

    def predefined_rules do
      %{
        "recommended" =>
          rule :and do
            ["company_name" == "Telex", "revenue" > 1_000_000_000]
          end
      }
    end
  end

  describe "build/1" do
    test "basic rules" do
      rule = %{
        and: [
          %{
            name: "startup",
            operator: "exists"
          },
          %{
            name: "department",
            operator: "eq",
            values: ["Technology"]
          },
          %{
            name: "department",
            operator: "eq",
            values: ["Technology"]
          }
        ],
        or: [
          %{
            name: "department",
            operator: "eq",
            values: ["deparment"]
          }
        ],
        not: [
          %{
            name: "department",
            operator: "eq",
            values: ["student"]
          }
        ],
        filter: [
          exists?("startup"),
          1 in [1, 2],
          %{
            name: "colleges.students.name",
            operator: "eq",
            values: ["test", "test1"]
          }
        ]
      }

      expected_query = %{
        bool: %{
          filter: [
            %{exists: %{field: "startup"}},
            %{terms: %{"1": [1, 2]}},
            %{terms: %{"colleges.students.name": ["test", "test1"]}}
          ],
          should: [%{terms: %{department: ["deparment"]}}],
          must: [
            %{exists: %{field: "startup"}},
            %{terms: %{department: ["Technology"]}},
            %{terms: %{department: ["Technology"]}}
          ],
          must_not: [%{terms: %{department: ["student"]}}]
        }
      }

      assert ^expected_query = TestRuleParser.build(rule)
    end

    test "test build with timestamp range" do
      rule = %{
        and: [
          %{
            name: "timestamp",
            operator: "gt",
            values: [20]
          },
          %{
            name: "time",
            operator: ["gt", "gte", "lt", "lte"],
            values: [20, 30]
          }
        ]
      }

      expected_query = %{
        bool: %{
          must: [
            %{range: %{"timestamp" => %{gt: 20}}},
            %{range: %{"time" => %{"gt" => 20, "gte" => 30}}}
          ]
        }
      }

      assert ^expected_query = TestRuleParser.build(rule)
    end

    test "complex nested rules" do
      rule = %{
        and: [
          %{
            name: "test",
            operator: "eq",
            values: "elastic"
          },
          %{
            and: %{
              name: "test",
              operator: "eq",
              values: "elastic_search"
            },
            or: %{
              name: "test",
              operator: "eq",
              values: "query"
            }
          },
          %{
            name: "time",
            operator: ["gt", "gte", "lt", "lte"],
            values: [20, 30]
          }
        ],
        or: 1 in [1, 2]
      }

      assert %{
               bool: %{
                 should: [%{terms: %{"1": [1, 2]}}],
                 must: [
                   %{term: %{test: "elastic"}},
                   %{range: %{"time" => %{"gt" => 20, "gte" => 30}}},
                   %{
                     bool: %{
                       should: [%{term: %{test: "query"}}],
                       must: [%{term: %{test: "elastic_search"}}]
                     }
                   }
                 ]
               }
             } = TestRuleParser.build(rule)
    end

    test "complex multi nested rules" do
      rule = %{
        and: [
          %{
            and: %{
              name: "status",
              operator: "eq",
              values: "active"
            },
            or: [
              %{
                and: %{
                  name: "category",
                  operator: "eq",
                  values: "electronics"
                }
              },
              %{
                and: %{
                  name: "category",
                  operator: "eq",
                  values: "furniture"
                }
              }
            ]
          },
          %{
            name: "date",
            operator: ["gte", "lte"],
            values: ["2024-01-01", "2024-12-31"]
          }
        ]
      }

      expected_query = %{
        bool: %{
          must: [
            %{
              range: %{
                "date" => %{
                  "gte" => "2024-01-01",
                  "lte" => "2024-12-31"
                }
              }
            },
            %{
              bool: %{
                should: [
                  %{
                    bool: %{
                      must: [%{term: %{category: "electronics"}}]
                    }
                  },
                  %{
                    bool: %{must: [%{term: %{category: "furniture"}}]}
                  }
                ],
                must: [%{term: %{status: "active"}}]
              }
            }
          ]
        }
      }

      assert ^expected_query = TestRuleParser.build(rule)
    end

    @tag timeout: :infinity
    test "complex query with nested rules" do
      rule = %{
        and: [
          %{
            name: "status",
            operator: "eq",
            values: "active"
          },
          %{
            name: "date",
            operator: ["gte", "lte"],
            values: ["2024-01-01", "2024-12-31"]
          },
          %{
            and: %{
              name: "reviews.rating",
              operator: "gte",
              values: ["4"]
            }
          }
        ],
        or: [
          %{
            name: "category",
            operator: "eq",
            values: "electronics"
          },
          %{
            name: "category",
            operator: "eq",
            values: "furniture"
          }
        ],
        filter: [
          %{
            name: "price",
            operator: "gte",
            values: ["50"]
          },
          exists?("brand")
        ],
        not: [
          %{
            name: "discounted",
            operator: "eq",
            values: true
          }
        ]
      }

      expected_query = %{
        bool: %{
          filter: [
            %{range: %{"price" => %{gte: "50"}}},
            %{exists: %{field: "brand"}}
          ],
          should: [
            %{term: %{category: "electronics"}},
            %{term: %{category: "furniture"}}
          ],
          must: [
            %{term: %{status: "active"}},
            %{
              range: %{
                "date" => %{
                  "gte" => "2024-01-01",
                  "lte" => "2024-12-31"
                }
              }
            },
            %{
              bool: %{
                must: [%{range: %{"reviews.rating" => %{gte: "4"}}}]
              }
            }
          ],
          must_not: [%{term: %{discounted: true}}]
        }
      }

      assert ^expected_query = TestRuleParser.build(rule)
    end






































    test "supports predefined rules" do
      expected_query = %{
        bool: %{
          must: [
            %{
              bool: %{
                must: [
                  %{bool: %{must: %{bool: %{must: [%{terms: %{"company_name" => ["telex"]}}]}}}},
                  %{
                    bool: %{
                      must: %{bool: %{must: [%{range: %{"revenue" => %{gt: 1_000_000_000}}}]}}
                    }
                  }
                ]
              }
            },
            %{bool: %{must: %{bool: %{must: [%{terms: %{"department" => ["technology"]}}]}}}}
          ]
        }
      }

      rule = %{
        "and" => [
          %{
            "type" => "predefined",
            "name" => "recommended"
          },
          %{
            "name" => "department",
            "type" => "attribute",
            "operator" => "eq",
            "values" => ["Technology"],
            "inverse" => false
          }
        ]
      }

      assert ^expected_query = TestRuleParser.build(rule)
    end

    test "returns es query for a simple rule with only attribute field_types" do
      rule =
        rule :and do
          [
            exists?("startup"),
            exists?("funding"),
            "department" in "Technology",
            "company_name" == "Telex",
            "revenue" > 1_000_000_000,
            "revenue" > 9_999_999_999
          ]
        end

      expected_query = %{
        bool: %{
          must: [
            %{exists: %{field: "startup"}},
            %{exists: %{field: "funding"}},
            %{terms: %{department: ["Technology"]}},
            %{terms: %{company_name: ["Telex"]}},
            %{range: %{"revenue" => %{gt: 1_000_000_000}}},
            %{range: %{"revenue" => %{gt: 9_999_999_999}}}
          ]
        }
      }

      assert ^expected_query = TestRuleParser.build(rule)
    end


    test "returns es query for a rule with AND & OR both clauses" do
      rule = %{
        "and" => [
          %{
            "type" => "attribute",
            "name" => "startup",
            "operator" => "exists",
            "inverse" => false
          }
        ],
        "or" => [
          %{
            "type" => "attribute",
            "name" => "department",
            "operator" => "eq",
            "values" => ["Technology"],
            "inverse" => false
          },
          %{
            "type" => "attribute",
            "name" => "funding",
            "operator" => "exists",
            "inverse" => true
          }
        ]
      }

      expected_query = %{
        bool: %{
          must: [
            %{
              bool: %{
                must: %{
                  bool: %{
                    must: [
                      %{
                        exists: %{field: "startup"}
                      }
                    ]
                  }
                }
              }
            }
          ],
          minimum_should_match: 1,
          should: [
            %{
              bool: %{
                must: %{
                  bool: %{
                    must: [
                      %{terms: %{"department" => ["technology"]}}
                    ]
                  }
                }
              }
            },
            %{
              bool: %{
                must_not: %{
                  bool: %{
                    must: [
                      %{
                        exists: %{field: "funding"}
                      }
                    ]
                  }
                }
              }
            }
          ]
        }
      }

      assert ^expected_query = TestRuleParser.build(rule)
    end

    test "returns es query for a rule with only OR clauses" do
      rule = %{
        "or" => [
          %{
            "type" => "attribute",
            "name" => "department",
            "operator" => "eq",
            "values" => ["Technology"],
            "inverse" => false
          },
          %{
            "type" => "attribute",
            "name" => "funding",
            "operator" => "exists",
            "inverse" => true
          }
        ]
      }

      expected_query = %{
        bool: %{
          minimum_should_match: 1,
          should: [
            %{
              bool: %{
                must: %{
                  bool: %{
                    must: [
                      %{terms: %{"department" => ["technology"]}}
                    ]
                  }
                }
              }
            },
            %{
              bool: %{
                must_not: %{
                  bool: %{
                    must: [
                      %{
                        exists: %{field: "funding"}
                      }
                    ]
                  }
                }
              }
            }
          ]
        }
      }

      assert ^expected_query = TestRuleParser.build(rule)
    end

    test "returns es query for a rule with operator timestamp_before" do
      current_time = DateTime.utc_now()

      rule = %{
        "and" => [
          %{
            "type" => "attribute",
            "name" => "timestamp",
            "operator" => "timestamp_before",
            "values" => [7],
            "inverse" => false,
            "current_time" => current_time
          }
        ]
      }

      start_datetime =
        current_time
        |> Timex.shift(days: +7)
        |> Timex.beginning_of_day()

      start_unix_timestamp = start_datetime |> DateTime.to_unix()

      end_unix_timestamp =
        start_datetime
        |> Timex.shift(days: 1)
        |> Timex.beginning_of_day()
        |> DateTime.to_unix()

      assert %{
               bool: %{
                 must: [
                   %{
                     range: %{
                       "timestamp" => %{
                         gte: ^start_unix_timestamp,
                         lt: ^end_unix_timestamp
                       }
                     }
                   }
                 ]
               }
             } = TestRuleParser.build(rule)
    end

    test "returns es query for a rule with operator timestamp_before when inverse true" do
      current_time = DateTime.utc_now()

      rule = %{
        "and" => [
          %{
            "type" => "attribute",
            "name" => "timestamp",
            "operator" => "timestamp_before",
            "values" => [7],
            "inverse" => true,
            "current_time" => current_time
          }
        ]
      }

      start_datetime =
        current_time
        |> Timex.shift(days: -7)
        |> Timex.beginning_of_day()

      start_unix_timestamp = start_datetime |> DateTime.to_unix()

      end_unix_timestamp =
        start_datetime
        |> Timex.shift(days: 1)
        |> Timex.beginning_of_day()
        |> DateTime.to_unix()

      assert %{
               bool: %{
                 must: [
                   %{
                     range: %{
                       "timestamp" => %{
                         gte: ^start_unix_timestamp,
                         lt: ^end_unix_timestamp
                       }
                     }
                   }
                 ]
               }
             } = TestRuleParser.build(rule)
    end
  end
end
