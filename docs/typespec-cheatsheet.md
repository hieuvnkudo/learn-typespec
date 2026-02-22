# 📘 TypeSpec Comprehensive Cheatsheet

## 1. Cấu trúc Chương trình & Không gian tên

| Thành phần | Cú pháp / Ví dụ | Ghi chú |
| --- | --- | --- |
| **Imports** | `import "./file.tsp";` <br> `import "@typespec/http";` | Phải bắt đầu bằng `./`, `../`, đường dẫn tuyệt đối hoặc tên thư viện. |
| **Using** | `using TypeSpec.Http;` | Mở scope của namespace để sử dụng type mà không cần tiền tố. |
| **Namespace** | `namespace MyApi;` (Blockless) <br> `namespace MyApi { ... }` (Block) | Gom nhóm các định nghĩa. Cho phép lồng nhau: `namespace A.B { ... }`. |

## 2. Hệ thống Kiểu dữ liệu (Types)

### 2.1 Scalars (Kiểu nguyên thủy)

* **Có sẵn:** `string`, `int8-64`, `uint8-64`, `float32-64`, `decimal`, `boolean`, `plainDate`, `utcDateTime`, `duration`, `bytes`, `url`, `uuid`.
* **Định nghĩa mới:** `scalar MyString extends string;`
* **Initializers:** `scalar ipv4 extends string { init fromInt(v: uint32); }`

### 2.2 Models (Cấu trúc dữ liệu)

```typespec
model User {
  id: string;                    // Bắt buộc
  age?: int32;                   // Tùy chọn
  role: string = "user";         // Giá trị mặc định
  "api-key": string;             // Tên thuộc tính có ký tự đặc biệt
  @doc("Ghi chú") name: string;  // Decorator trên thuộc tính
}

```

### 2.3 Model Composition (Phân cấp & Tái sử dụng)

* **`extends` (Inheritance):** `model Dog extends Animal {}` (Quan hệ cha-con thực sự).
* **`is` (Copy/Rename):** `model CreateUserRequest is User;` (Sao chép cấu trúc nhưng là type riêng).
* **`...` (Spread):** `model PatchUser { ...User }` (Copy mọi thuộc tính vào model hiện tại).

### 2.4 Enums & Unions

* **Enum:** Danh sách hằng số định danh.
```typespec
enum Color { Red: "red", Blue: "blue" }
enum States { ...OtherEnum, Pending } // Spread enum

```


* **Unions:** Một trong nhiều kiểu.
* *Expression:* `alias ID = string | int32;`
* *Named Union:* `union Pet { dog: Dog, cat: Cat }` (Giúp AI và Emitter định danh biến thể).



## 3. Operations & Interfaces

### 3.1 Operations (API Endpoints)

```typespec
@get op read(@path id: string): User | Error;
op upload(...CommonParams, @body data: bytes): void;
op create is GenericCreate<User>; // Reusing signature via 'is'

```

* **Meta-references:** `op::parameters` (Model chứa params), `op::returnType` (Kiểu trả về).

### 3.2 Interfaces

Nhóm các operation có liên quan. Có thể dùng `extends` để kế thừa interface khác.

```typespec
interface Store<T> {
  @get get(@path id: string): T;
  @post create(@body item: T): T;
}

```

## 4. Templates (Generics)

Cho phép tham số hóa các Models, Operations, Interfaces và Aliases.

* **Cơ bản:** `model Page<T> { items: T[] }`
* **Ràng buộc (Constraints):** `model Record<T extends string> { id: T }`
* **Giá trị mặc định:** `model Box<T = string> { content: T }`
* **Truyền tham số theo tên:** `alias MyPage = Page<T = User>;`

## 5. Decorators & Metadata

Decorators bắt đầu bằng `@` (trên type) hoặc `@@` (bên ngoài type).

* **Validation:** `@minLength(n)`, `@maxLength(n)`, `@minValue(n)`, `@maxValue(n)`, `@pattern("regex")`.
* **HTTP (Library):** `@route("/path")`, `@get`, `@post`, `@header`, `@query`, `@path`, `@body`, `@statusCode`.
* **Doc:** `@doc("Description")`, `@summary("Brief")`, `@example(value)`.
* **Visibility:** `@visibility("read", "create")`.

## 6. Type Literals & Intersections

* **Literals:** `"Admin"`, `100`, `true`, `null`.
* **Multi-line String:**
```tsp
alias MD = """
  Dòng 1
  Dòng 2
  """;

```


* **Intersections (`&`):** Kết hợp các type. `alias Admin = User & { admin: true }`.

---

## 7. Quy tắc Cú pháp "Vàng" (Dành cho AI & Người kiểm tra)

1. **Dấu chấm phẩy (`;`):**
* **Bắt buộc:** Sau `import`, `using`, `alias`, `scalar`, `op` (không có body), và khai báo model/enum/interface dạng một dòng (`model X is Y;`).
* **Không dùng:** Sau dấu đóng ngoặc nhọn `}` của model, interface, namespace, enum có block.


2. **Đa hình (Polymorphism):** Sử dụng `@discriminator("propertyName")` trên base model để các emitter (OpenAPI) xử lý đúng kế thừa.
3. **Alias vs Model:** `alias` bị xóa hoàn toàn khi compile (chỉ là macro), `model` luôn tồn tại trong output.
4. **Tuần tự hóa:** Tên thuộc tính trong dấu ngoặc kép `"prop-name"` nếu chứa ký tự đặc biệt.

---

## 8. Ví dụ Tổng hợp (Phù hợp cho Project của bạn)

```typespec
import "@typespec/http";
using TypeSpec.Http;

@service({ title: "Social Education API" })
namespace EducationService;

model BaseResource {
  @visibility("read") id: string;
  createdAt: utcDateTime;
}

@doc("Thông tin người dùng")
model User extends BaseResource {
  @minLength(3) username: string;
  @format("email") email: string;
}

@route("/users")
interface UserOperations {
  @get list(@query search?: string): User[];
  @post create(@body user: User): User | { @statusCode _: 400, message: string };
}

```