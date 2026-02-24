import "@typespec/http";
import "@typespec/openapi";
import "@typespec/versioning";

using Http;
using TypeSpec.OpenAPI;
using Versioning;

@doc("""
API Pet Store mẫu để minh hoạ TypeSpec (REST + OpenAPI).

- v1: CRUD pets
- v2: thêm resource toys theo từng pet
""")
@service(#{ title: "Pet Store" })
@server("https://example.com", "Single server endpoint")
@versioned(Versions)
namespace PetStore;

@doc("Danh sách version của API.")
enum Versions {
  v1: "1.0",
  v2: "2.0",
}

@doc("Thông tin một thú cưng (Pet) trong hệ thống.")
model Pet {
  @doc("Định danh của pet.")
  id: int32;

  @minLength(1)
  @doc("Tên của pet (bắt buộc, tối thiểu 1 ký tự).")
  name: string;

  @minValue(0)
  @maxValue(100)
  @doc("Tuổi của pet (0-100).")
  age: int32;

  @doc("Loại pet.")
  kind: petType;
}

@doc("Tập giá trị cho loại pet.")
enum petType {
  dog: "dog",
  cat: "cat",
  fish: "fish",
  bird: "bird",
  reptile: "reptile",
}

@added(Versions.v2)
@doc("Đồ chơi của pet (chỉ có từ v2).")
model Toy {
  @doc("Định danh của toy.")
  id: int32;
  @doc("Tên của toy.")
  name: string;
}

@doc("Các tham số dùng chung cho nhiều operation (headers/query).")
model CommonParameters {
  @header
  @doc("Mã request để trace/log (correlation id).")
  requestID: string;

  @query
  @doc("Ngôn ngữ/locale cho nội dung trả về.")
  locale?: string;

  @header
  @doc("Phiên bản client gọi API.")
  clientVersion?: string;
}

// highlight-start
model PetListResponse {
  ...OkResponse;
  ...Body<Pet[]>;
}

model PetResponse {
  ...OkResponse;
  ...Body<Pet>;
}

model PetCreatedResponse {
  ...CreatedResponse;
  ...Body<Pet>;
}

model PetAcceptedResponse {
  ...AcceptedResponse;
  ...Body<Pet>;
}

model PetErrorResponse {
  ...BadRequestResponse;
  ...Body<ValidationError>;
}

model PetNotFoundResponse {
  ...NotFoundResponse;
  ...Body<NotFoundError>;
}

model PetUnauthorizedResponse {
  ...UnauthorizedResponse;
  ...Body<UnauthorizedError>;
}

model PetSuccessResponse {
  ...OkResponse;
  ...Body<string>;
}

model PetNoContentResponse {
  ...NoContentResponse;
}
// highlight-end

@route("/pets")
@tag("Pets")
@doc("Nhóm API quản lý thú cưng (Pet).")
namespace Pets {
  @get
  // highlight-next-line
  @summary("Liệt kê danh sách pets")
  @doc("Trả về danh sách pet. Hỗ trợ các tham số chung như locale/requestID.")
  op listPets(...CommonParameters): PetListResponse;

  @get
  // highlight-start
  @summary("Lấy chi tiết một pet")
  @doc("Trả về pet theo petId. Có thể trả 404 nếu không tồn tại.")
  op getPet(@path petId: int32, @header ifMatch?: string): PetResponse | PetNotFoundResponse;
  // highlight-end
  @useAuth(BearerAuth)
  @post
  // highlight-start
  @summary("Tạo mới một pet")
  @doc("Yêu cầu xác thực Bearer. Tạo pet mới và trả 201 hoặc 202; có thể trả 400/401.")
  op createPet(@body pet: Pet):
    | PetCreatedResponse
    | PetAcceptedResponse
    | PetErrorResponse
    | PetUnauthorizedResponse;
  // highlight-end

  @useAuth(BearerAuth)
  @put
  // highlight-start
  @summary("Cập nhật một pet")
  @doc("Yêu cầu xác thực Bearer. Cập nhật pet theo petId; có thể trả 400/401/404/500.")
  op updatePet(@path petId: int32, @body pet: Pet):
    | PetResponse
    | PetErrorResponse
    | PetUnauthorizedResponse
    | PetNotFoundResponse
    | InternalServerErrorResponse;
  // highlight-end

  @useAuth(BearerAuth)
  @delete
  // highlight-start
  @summary("Xoá một pet")
  @doc("Yêu cầu xác thực Bearer. Xoá pet theo petId và trả 204; có thể trả 401.")
  op deletePet(@path petId: int32): PetNoContentResponse | PetUnauthorizedResponse;
  // highlight-end

  @route("{petId}/toys")
  @tag("Toys")
  @doc("Nhóm API quản lý đồ chơi (Toy) theo từng pet. Chỉ có từ v2.")
  namespace Toys {
    @added(Versions.v2)
    @get
    @summary("Liệt kê đồ chơi của pet")
    @doc("Trả về danh sách toy theo petId (v2).")
    op listToys(@path petId: int32, ...CommonParameters): {
      @body toys: Toy[];
    };

    @added(Versions.v2)
    @post
    @useAuth(BearerAuth)
    @summary("Tạo mới một đồ chơi")
    @doc("Yêu cầu xác thực Bearer. Tạo toy mới cho pet (v2).")
    op createToy(@path petId: int32, @body toy: Toy, ...CommonParameters): {
      @statusCode statusCode: 201;
      @body newToy: Toy;
    };

    @added(Versions.v2)
    @put
    @useAuth(BearerAuth)
    @summary("Cập nhật một đồ chơi")
    @doc("Yêu cầu xác thực Bearer. Cập nhật toy theo petId/toyId (v2).")
    op updateToy(@path petId: int32, @path toyId: int32, @body toy: Toy, ...CommonParameters): {
      @body updatedToy: Toy;
    };

    @added(Versions.v2)
    @delete
    @useAuth(BearerAuth)
    @summary("Xoá một đồ chơi")
    @doc("Yêu cầu xác thực Bearer. Xoá toy theo petId/toyId và trả 204 (v2).")
    op deleteToy(@path petId: int32, @path toyId: int32, ...CommonParameters): {
      @statusCode statusCode: 204;
    };
  }
}

@error
@doc("Lỗi khi không tìm thấy tài nguyên yêu cầu.")
model NotFoundError {
  @doc("Mã lỗi cố định.")
  code: "NOT_FOUND";
  @doc("Thông điệp mô tả lỗi.")
  message: string;
}

@error
@doc("Lỗi validate dữ liệu đầu vào.")
model ValidationError {
  @doc("Mã lỗi cố định.")
  code: "VALIDATION_ERROR";
  @doc("Thông điệp mô tả lỗi.")
  message: string;
  @doc("Danh sách chi tiết các lỗi validate.")
  details: string[];
}

@error
@doc("Lỗi xác thực/không có quyền truy cập.")
model UnauthorizedError {
  @doc("Mã lỗi cố định.")
  code: "UNAUTHORIZED";
  @doc("Thông điệp mô tả lỗi.")
  message: string;
}

@error
@doc("Lỗi không xác định phía server.")
model InternalServerError {
  @doc("Mã lỗi cố định.")
  code: "INTERNAL_SERVER_ERROR";
  @doc("Thông điệp mô tả lỗi.")
  message: string;
}

model InternalServerErrorResponse {
  @statusCode statusCode: 500;
  @body error: InternalServerError;
}