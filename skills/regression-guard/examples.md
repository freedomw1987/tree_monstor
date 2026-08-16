## Regression guard 多語言實現示例

以下是Regression-guard 可以參考的例子：

```markdown
### TypeScript
```typescript
import { probe, assert, describe } from './probes';

describe('User Module', () => {
  probe('login returns user', actual, expected);
  assert(user.id === 1, 'User ID should be 1');
});
```

### Python

```python
from probes import probe, assert_, describe

@describe('User Module')
def test_user():
    probe('login returns user', actual, expected)
    assert_(user.id == 1, 'User ID should be 1')
```

### Go

```go
import "probes"

probes.Describe("User Module", func() {
    probes.Probe("login returns user", actual, expected)
    probes.Assert(user.Id == 1, "User ID should be 1")
})
```

### Rust

```rust
use probes::{probe, assert, describe};

describe!("User Module", || {
    probe!("login returns user", actual, expected);
    assert!(user.id == 1, "User ID should be 1");
});
```

### Java

```java
import static probes.Probes.*;

describe("User Module", () -> {
    probe("login returns user", actual, expected);
    assert(user.getId() == 1, "User ID should be 1");
});
```

### Ruby

```ruby
require 'probes'

describe 'User Module' do
  probe 'login returns user', actual, expected
  assert user.id == 1, 'User ID should be 1'
end
```

### PHP

```php
<?php
use probes\probe;
use probes\describe;

describe('User Module', function() {
    probe('login returns user', $actual, $expected);
    assert($user->id === 1, 'User ID should be 1');
});
```

```

```

