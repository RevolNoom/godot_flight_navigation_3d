# Coding Best Practices

## Readability

### Limit lines to 65 characters

## General guidelines

### Arrange code for early return whenever possible

#### Example 1: C#

##### Bad
public void ValidateInput(InputObject input)
{
  if (input != null) 
  {
    // Perform validation logic
  }
}

##### Good
public void ValidateInput(InputObject input)
{
  if (input == null) 
  {
    return;
  }
  // Perform validation logic
}

### Functions must explicitly return results and reassign at caller. Do not modify parameters internally.

#### Example 1: C#

##### Bad
public void GenerateUserCode(List<User> users)
{
  foreach (var user in users)
  {
    user.code = GenerateCodeFromName(user.name);
  }
}

public void PerformBusinessLogic()
{
  var users = GetUsers();
  GenerateUserCode(users);
}

##### Good
public List<string> GenerateUserCode(List<User> users)
{
  return users.Select(user => GenerateCodeFromName(user.name)).ToList();
}

public void PerformBusinessLogic()
{
  var users = GetUsers();
  var userCodes = GenerateUserCode(users);
  for (int i = 0; i < users.Count; ++i)
  {
    users[i].code = userCodes[i];
  }
}

### Comments

#### Only adding comments is accepted. Do not remove existing comments.

#### Place the comment on a separate line, not at the end of a line of code.

#### Begin comment text with an uppercase letter.

#### End comment text with a period.

#### Insert one space between the comment delimiter and the comment text.

### Static members

#### Call static members by using the class name

#### Do not qualify a static member defined in a base class with the name of a derived class

### Return variable, not function call.

#### Example 1: C#
##### Good
var result = Calculate(listData);
return result;

##### Bad
return Calculate (listData);

### Pass variables as arguments into function calls, not calculation.
#### Example 1: C#
##### Bad
ValidateNames(users.Select(user => user.name));

##### Good
var userNames = users.Select(user => user.name);
ValidateNames(userNames);

## Create new object via constructors or by default constructor then assign each field. Avoid using initializer.
This helps when field initialization calls functions that might throw exceptions. 
Exceptions will be thrown at the point of assignment, making debugging easier.
This applies for types that are not index-able (array, dictionary,...).

### Example 1: C#
##### Bad
var user = new User() {
    user_type = UserType.Customer,
    user_type_name = GetUserTypeName(UserType.Customer),
};

##### Good
var user = new User();
user.user_type = UserType.Customer;
user.user_type_name = GetUserTypeName(UserType.Customer);

## Array manipulation

### Use for-each loop syntax or traditional for loop instead of ForEach() function.

#### Example 1: C#
##### Bad
users.ForEach(user => { user.user_id = Guid.NewGuid(); });

##### Good
foreach (var user in users)
{
user.user_id = Guid.NewGuid();
}

##### Good
for (int i = 0; i < users.Count; i++)
{
var user = users[i];
user.user_id = Guid.NewGuid();
}

### Non-transformative step

#### Definitions

A step that return an array of same type as input array.

##### Examples
###### Filtering
- C#: Where()
- JavaScript/TypeScript: filter()
###### Ordering:
- C#: OrderBy()
- JavaScript/TypeScript: sort()

#### Rules

##### Reassign results to initial variable whenever possible

####### Example 1: C#
var users = GetUsers();
// Survey business only consider individual customers, not companies
users = users.Where(user => user.type == UserType.Customer);
// This is a survey for elderly powder milk, so we care only about old people
users = users.Where(user => user.age > UserAgeThreshold.Elderly);


### Transformative step

A step that return an array of different type from input array.
If the return type is identical to the input type, it is considered non-transformative.

#### Examples: C#

##### Transformative

List<int> numbers = new List<int> { 1, 2, 3, 4, 5 };
List<User> users = numbers.Select(num => { 
var user = new User();
user.user_type = num; 
return user; 
}).ToList();

##### Non-transformative

List<int> numbers = new List<int> { 1, 2, 3, 4, 5 };
numbers = numbers.Select(n => n + 1).ToList();

##### Rules

###### Assigns intermediate results into variables.

### Rules

#### Explain each step with comments.