@quarkus
Feature: Deploy quarkus service

  Background:
    Given Namespace is created

  Scenario Outline: Deploy drools-quarkus-example service without persistence and native <native>
    Given Kogito Operator is deployed
    When Deploy quarkus example service "ruleunit-quarkus-example" with configuration:
      | config | native | <native> |
    Then Kogito application "ruleunit-quarkus-example" has 1 pods running within <minutes> minutes
    And HTTP POST request on service "ruleunit-quarkus-example" is successful within 2 minutes with path "find-approved" and body:
       """json
       {
         "maxAmount" : 5000,
         "loanApplications": [{ 
            "id" : "ABC10001",
            "amount" : 2000,
            "deposit" : 100,
            "applicant": {
              "age" : 45,
              "name" : "John"
            }
          }, {
            "id" : "ABC10002",
            "amount" : 5000,
            "deposit" : 100,
            "applicant" : {
              "age" : 25,
              "name" : "Paul"
            }
          }, {
            "id" : "ABC10015",
            "amount" : 1000,
            "deposit" : 100,
            "applicant" : {
              "age" : 12,
              "name" : "George"
            }
          }]
        }
      """

    @smoke  
    Examples:
      | native   | minutes |
      | disabled | 10      |

    @native
    Examples:
      | native  | minutes |
      | enabled | 20      |

#####

  @persistence
  @infinispan
  Scenario Outline: Deploy process-quarkus-example service with persistence and native <native>
    Given Kogito Operator is deployed with Infinispan operator
    And Deploy quarkus example service "process-quarkus-example" with configuration:
      | config | native      | <native> |
      | config | persistence | enabled  |
    And Kogito application "process-quarkus-example" has 1 pods running within <minutes> minutes
    And Start "orders" process on service "process-quarkus-example" within 3 minutes with body:
      """json
      {
        "approver" : "john", 
        "order" : {
          "orderNumber" : "12345", 
          "shipped" : false
        }
      }
      """
    And Service "process-quarkus-example" contains 1 instances of process with name "orders"
    
    When Scale Kogito application "process-quarkus-example" to 0 pods within 2 minutes
    And Scale Kogito application "process-quarkus-example" to 1 pods within 2 minutes
    
    Then Service "process-quarkus-example" contains 1 instances of process with name "orders" within 2 minutes
    
    Examples:
      | native   | minutes |
      | disabled | 10      |

    @native
    Examples:
      | native  | minutes |
      | enabled | 20      |

#####

  # Disabled as long as https://issues.redhat.com/browse/KOGITO-1163 and https://issues.redhat.com/browse/KOGITO-1166 is not solved
  @disabled
  @jobsservice
  Scenario Outline: Deploy process-timer-quarkus service with Jobs service and native <native>
    Given Kogito Operator is deployed
    And Install Kogito Jobs Service with 1 replicas
    And Deploy quarkus example service "process-timer-quarkus" with configuration:
      | config | native | <native> |
    And Kogito application "process-timer-quarkus" has 1 pods running within <minutes> minutes

    When Start "timer" process on service "process-timer-quarkus" within 2 minutes with body:
      """json
      { }
      """

    # Implement retrieving of job information from Jobs service once https://issues.redhat.com/browse/KOGITO-1163 is fixed
    Then Kogito application "process-timer-quarkus" log contains text "Before timer" within 1 minutes
    And Kogito application "process-timer-quarkus" log contains text "After timer" within 1 minutes

    Examples:
      | native   | minutes |
      | disabled | 10      |

    # Disabled as long as https://issues.redhat.com/browse/KOGITO-1179 is not solved
    @disabled
    @native
    Examples:
      | native  | minutes |
      | enabled | 20      |

#####

  @events
  @infinispan
  @kafka
  Scenario Outline: Data Index retrieves Quarkus process' events with native <native>
    Given Kogito Operator is deployed with Infinispan and Kafka operators
    And Install Kogito Data Index with 1 replicas
    And Deploy quarkus example service "process-quarkus-example" with configuration:
      | config        | native      | <native> |
      | config        | persistence | enabled  |
      | config        | events      | enabled  |
      | build-request | cpu         | <build-request-cpu>     |
      | build-request | memory      | <build-request-memory>  |
      | build-limit   | cpu         | <build-limit-cpu>       |
    And Kogito application "process-quarkus-example" has 1 pods running within <minutes> minutes

    When Start "orders" process on service "process-quarkus-example" within 3 minutes with body:
      """json
      {
        "approver" : "john", 
        "order" : {
          "orderNumber" : "12345", 
          "shipped" : false
        }
      }
      """

    Then GraphQL request on Data Index service returns ProcessInstances processName "orders" within 2 minutes

    Examples:
      | native   | minutes | build-request-cpu | build-limit-cpu | build-request-memory |
      | disabled | 10      | 1                 | 4               | 4Gi                  |

    @native
    Examples:
      | native   | minutes | build-request-cpu | build-limit-cpu | build-request-memory |
      | enabled  | 20      | 4                 | 8               | 10Gi                 |

#####

  @usertasks
  Scenario Outline: Deploy process-quarkus-example service to complete user tasks and native <native>
    Given Kogito Operator is deployed
    And Deploy quarkus example service "process-quarkus-example" with configuration:
      | config | native      | <native> |
      | config | persistence | disabled |
    And Kogito application "process-quarkus-example" has 1 pods running within <minutes> minutes

    When Start "orders" process on service "process-quarkus-example" within 3 minutes with body:
      """json
      {
        "approver" : "john", 
        "order" : {
          "orderNumber" : "12345", 
          "shipped" : false
        }
      }
      """
    Then Service "process-quarkus-example" contains 1 instances of process with name "orders"

    When Complete "Verify order" task on service "process-quarkus-example" and process with name "orderItems" by user "john" with body:
	  """json
	  {}
    """

    Then Service "process-quarkus-example" contains 0 instances of process with name "orders"
    And Service "process-quarkus-example" contains 0 instances of process with name "orderItems"

    Examples:
      | native   | minutes |
      | disabled | 10      |

    @native
    Examples:
      | native  | minutes |
      | enabled | 20      |

#####

  @persistence
  @infinispan
  Scenario: Deploy process-quarkus-example service with persistence using external Infinispan
    Given Kogito Operator is deployed with Infinispan operator
    And Infinispan instance "external-infinispan" is deployed with configuration:
      | username | developer |
      | password | mypass    |
    And Deploy quarkus example service "process-quarkus-example" with configuration:
      | infinispan | username    | developer                 |
      | infinispan | password    | mypass                    |
      | infinispan | uri         | external-infinispan:11222 |
    And Kogito application "process-quarkus-example" has 1 pods running within 10 minutes
    And Start "orders" process on service "process-quarkus-example" within 3 minutes with body:
      """json
      {
        "approver" : "john", 
        "order" : {
          "orderNumber" : "12345", 
          "shipped" : false
        }
      }
      """
    And Service "process-quarkus-example" contains 1 instances of process with name "orders"

    When Scale Kogito application "process-quarkus-example" to 0 pods within 2 minutes
    And Scale Kogito application "process-quarkus-example" to 1 pods within 2 minutes

    Then Service "process-quarkus-example" contains 1 instances of process with name "orders" within 2 minutes
    # Native application is not tested as the test is very expensive and the external Infinispan configuration shouldn't have any effect on build type

#####

  @events
  @kafka
  @infinispan
  Scenario: Data Index retrieves Quarkus process events using external Kafka
    Given Kogito Operator is deployed with Infinispan and Kafka operators
    And Kafka instance "external-kafka" is deployed
    And Install Kogito Data Index with 1 replicas with configuration:
      | kafka | externalURI | external-kafka-kafka-bootstrap:9092 |
    And Deploy quarkus example service "process-quarkus-example" with configuration:
      | kafka | externalURI | external-kafka-kafka-bootstrap:9092 |
    And Kogito application "process-quarkus-example" has 1 pods running within 10 minutes

    When Start "orders" process on service "process-quarkus-example" within 3 minutes with body:
      """json
      {
        "approver" : "john", 
        "order" : {
          "orderNumber" : "12345", 
          "shipped" : false
        }
      }
      """

    Then GraphQL request on Data Index service returns ProcessInstances processName "orders" within 2 minutes
    # Native application is not tested as the test is very expensive and the external Kafka configuration shouldn't have any effect on build type
