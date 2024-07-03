defmodule RuleEngine.RuleParserTest do
  use ExUnit.Case, async: true
  use RuleEngine.RuleBuilder

  defmodule TestRuleParser do
    use RuleEngine.RuleParser,
      adapter: RuleEngine.Adapters.Elasticsearch

    use RuleEngine.RuleBuilder

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
            },
            %{
              bool: %{
                must: %{
                  bool: %{
                    must: [
                      %{
                        exists: %{field: "funding"}
                      }
                    ]
                  }
                }
              }
            },
            %{
              bool: %{
                must: %{
                  bool: %{must: [%{exists: %{field: "___improbable_field_name___"}}]}
                }
              }
            },
            %{
              bool: %{
                must: %{bool: %{must: [%{terms: %{"company_name" => ["telex"]}}]}}
              }
            },
            %{
              bool: %{
                must: %{bool: %{must: [%{range: %{"revenue" => %{gt: 1_000_000_000}}}]}}
              }
            },
            %{
              bool: %{
                must: %{bool: %{must: [%{range: %{"revenue" => %{gt: 9_999_999_999}}}]}}
              }
            }
          ]
        }
      }

      assert ^expected_query = TestRuleParser.build(rule)
    end

    test "returns es query for a nested rule with only attribute field_types" do
      rule = %{
        "and" => [
          %{
            "type" => "attribute",
            "name" => "startup",
            "operator" => "exists",
            "inverse" => false
          },
          %{
            "type" => "attribute",
            "name" => "funding",
            "operator" => "exists",
            "inverse" => true
          },
          %{
            "type" => "attribute",
            "name" => "department",
            "operator" => "eq",
            "values" => ["Technology"],
            "inverse" => false
          },
          %{
            "type" => "attribute",
            "name" => "company_name",
            "operator" => "eq",
            "values" => ["Telex"],
            "inverse" => true
          },
          %{
            "or" => [
              %{
                "type" => "attribute",
                "name" => "startup",
                "operator" => "exists",
                "inverse" => false
              },
              %{
                "type" => "attribute",
                "name" => "funding",
                "operator" => "exists",
                "inverse" => true
              },
              %{
                "type" => "attribute",
                "name" => "department",
                "operator" => "eq",
                "values" => ["Technology"],
                "inverse" => false
              },
              %{
                "type" => "attribute",
                "name" => "company_name",
                "operator" => "eq",
                "values" => ["Telex"],
                "inverse" => true
              },
              %{
                "and" => [
                  %{
                    "type" => "attribute",
                    "name" => "startup",
                    "operator" => "exists",
                    "inverse" => false
                  },
                  %{
                    "type" => "attribute",
                    "name" => "funding",
                    "operator" => "exists",
                    "inverse" => true
                  },
                  %{
                    "type" => "attribute",
                    "name" => "department",
                    "operator" => "eq",
                    "values" => ["Technology"],
                    "inverse" => false
                  },
                  %{
                    "type" => "attribute",
                    "name" => "company_name",
                    "operator" => "eq",
                    "values" => ["Telex"],
                    "inverse" => true
                  },
                  %{
                    "type" => "attribute",
                    "name" => "revenue",
                    "operator" => "gt",
                    "values" => [1_000_000_000],
                    "inverse" => false
                  },
                  %{
                    "type" => "attribute",
                    "name" => "revenue",
                    "operator" => "gt",
                    "values" => [9_999_999_999],
                    "inverse" => true
                  }
                ]
              }
            ]
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
                      %{exists: %{field: "startup"}}
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
                      %{exists: %{field: "funding"}}
                    ]
                  }
                }
              }
            },
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
                      %{terms: %{"company_name" => ["telex"]}}
                    ]
                  }
                }
              }
            },
            %{
              bool: %{
                should: [
                  %{
                    bool: %{
                      must: %{
                        bool: %{
                          must: [%{exists: %{field: "startup"}}]
                        }
                      }
                    }
                  },
                  %{
                    bool: %{
                      must_not: %{
                        bool: %{
                          must: [%{exists: %{field: "funding"}}]
                        }
                      }
                    }
                  },
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
                            %{terms: %{"company_name" => ["telex"]}}
                          ]
                        }
                      }
                    }
                  },
                  %{
                    bool: %{
                      must: [
                        %{
                          bool: %{
                            must: %{
                              bool: %{
                                must: [%{exists: %{field: "startup"}}]
                              }
                            }
                          }
                        },
                        %{
                          bool: %{
                            must_not: %{
                              bool: %{
                                must: [
                                  %{exists: %{field: "funding"}}
                                ]
                              }
                            }
                          }
                        },
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
                                  %{terms: %{"company_name" => ["telex"]}}
                                ]
                              }
                            }
                          }
                        },
                        %{
                          bool: %{
                            must: %{
                              bool: %{
                                must: [
                                  %{
                                    range: %{
                                      "revenue" => %{gt: 1_000_000_000}
                                    }
                                  }
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
                                    range: %{
                                      "revenue" => %{gt: 9_999_999_999}
                                    }
                                  }
                                ]
                              }
                            }
                          }
                        }
                      ]
                    }
                  }
                ]
              }
            }
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
