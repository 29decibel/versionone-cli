# where
A filter token is used to limit the results of an asset query. For example you may wish to filter a list of Story assets to only those that have 0 To Do. Note that Value arguments are or'd together while major terms of the filter are either AND'd or OR'd together depending on the Logical seperator. Value arguments are surrounded by single quotation marks and separated by commas.

Formal Syntax

{ AttributeDefinition Operator ' Value ' [ , ... ] } [ Logical ... ]

Arguments

AttributeDefinition
Is the attribute token you wish to filter on
Operator
Supported operators include =, !=, <, >, <=, and >=
Value
Any number or string that you wish to match against, must be surrounded with single-quote marks. To use either single- or double-quote marks within the value, enter the character twice in succession.
Logical
Use ; to denote the logical operation AND between two terms Use | to denote the logical operation OR between two terms
Note when using a mixture of logical AND and OR operators it may become necessary to group terms together. To do so surround the specific terms with parenthesises.
Examples

ToDo='0'. Filter assets to only those that have 0 To Do

ToDo!='0';Owners='Member:20'. Filter assets to only those that have a non-zero To Do and are owned by Member with ID 20.

ToDo!='0';Owners='Member:20','Member:21','Member:22'. Filter assets to only those that have a non-zero To Do and are owned by a Member with ID 20, 21, or 22.

Name='Can''t Boot'. Filter assets to only those whose name is equal to the string "Can't Boot". Notice the quote character has been escaped by doubling.

Owners.@Count>'5'. Filter assets to only those that are owned by more than 5 Members.

Estimate<'1'. Filter assets to only those that have an Estimate less than 1.

Owners='Member:20','Member:21'|Scope='Scope:5'. Filter assets to only those that are owned by a Member with ID 20 or 21 OR belong to a Scope (Project) with ID 5.

(ToDo!='0';Owners='Member:20')|(ToDo='0';Owners='Member:20','Member:21'). Filter assets to only those that have a non-zero To Do AND are owned by a Member with ID 20 OR those that have a 0 To Do AND are owned by a Member with ID 20 or 21.
