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

@doc("API contract cho social-network-ui (main API + message service).")
@service(#{ title: "Etechs Social Network" })
@server("https://example.com/api", "Main API base (UI config maps to /api)")
@versioned(SocialVersions)
namespace SocialNetwork {

@doc("Version list (chỉ v1).")
enum SocialVersions {
  v1: "1.0",
}

@doc("Envelope response chuẩn như middleware/UI: success + data + request_id.")
model ApiResponse<T> {
  success: true;
  data: T;
  request_id?: string;
}

@doc("Error envelope chuẩn như middleware/UI: success=false + error + request_id.")
model ApiErrorResponse {
  success: false;
  error: ApiError;
  request_id?: string;
}

@doc("Error payload chuẩn cho UI.")
model ApiError {
  code: string;
  message?: string;
  details?: unknown;
}

model OkEnvelopeResponse<T> {
  ...OkResponse;
  ...Body<ApiResponse<T>>;
}

model CreatedEnvelopeResponse<T> {
  ...CreatedResponse;
  ...Body<ApiResponse<T>>;
}

model NoContentEnvelopeResponse {
  ...NoContentResponse;
}

model BadRequestEnvelopeResponse {
  ...BadRequestResponse;
  ...Body<ApiErrorResponse>;
}

model UnauthorizedEnvelopeResponse {
  ...UnauthorizedResponse;
  ...Body<ApiErrorResponse>;
}

model NotFoundEnvelopeResponse {
  ...NotFoundResponse;
  ...Body<ApiErrorResponse>;
}

model InternalServerErrorEnvelopeResponse {
  @statusCode statusCode: 500;
  @body body: ApiErrorResponse;
}

@doc("Headers auth bắt buộc như UI.")
model AuthHeaders {
  @header("Authorization")
  authorization: string;

  @header("X-Tenant-Slug")
  tenant_slug: string;
}

@doc("Pagination query params.")
model PaginationQuery {
  @query
  page?: int32;

  @query("page_size")
  page_size?: int32;
}

@doc("Visibility setting.")
enum Visibility {
  PUBLIC: "PUBLIC",
  FRIENDS: "FRIENDS",
  PRIVATE: "PRIVATE",
}

@doc("Post type.")
enum PostType {
  SOCIAL: "SOCIAL",
  JOB: "JOB",
  QUESTION: "QUESTION",
}

@doc("Reaction type.")
enum ReactionType {
  LIKE: "LIKE",
  LOVE: "LOVE",
  HAHA: "HAHA",
  WOW: "WOW",
  SAD: "SAD",
  ANGRY: "ANGRY",
}

@doc("Gender.")
enum Gender {
  MALE: "MALE",
  FEMALE: "FEMALE",
  OTHER: "OTHER",
}

@doc("Role.")
enum Role {
  STUDENT: "STUDENT",
  TEACHER: "TEACHER",
  ADMIN: "ADMIN",
  STAFF: "STAFF",
}

@doc("Notification type.")
enum NotificationType {
  FRIEND_REQUEST: "FRIEND_REQUEST",
  FRIEND_ACCEPT: "FRIEND_ACCEPT",
  POST_LIKE: "POST_LIKE",
  POST_COMMENT: "POST_COMMENT",
  COMMENT_REPLY: "COMMENT_REPLY",
  MENTION: "MENTION",
  SYSTEM: "SYSTEM",
}

model Author {
  id: string;
  displayName: string;
  username: string;
  avatar: string | null;
  role?: string;
  accountStatus?: string;
}

enum PrivacyField {
  display_name: "display_name",
  birth_date: "birth_date",
  bio: "bio",
  avatar: "avatar",
  background: "background",
  personal_info: "personal_info",
}

model PrivacyOverride {
  field: PrivacyField;
  visibility: Visibility;
}

model UserPrivacy {
  default_visibility: Visibility;
  overrides?: PrivacyOverride[];
}

model PersonalInfo {
  educationLevel?: string;
  school?: string;
  class?: string;
  degree?: string;
  major?: string;
  graduationYear?: string;
  academicYear?: string;
  schoolYear?: string;
  favoriteSubjects?: string[];
  hobbies?: string[];
  location?: string;
}

model User {
  id: string;
  email: string;
  phone?: string | null;
  username: string;
  displayName: string;
  bio?: string;
  personalInfo?: PersonalInfo;
  birthDate?: string | null;
  avatarPath?: string;
  avatar?: string | null;
  backgroundPath?: string;
  background?: string | null;
  accountStatus: string;
  role: string;
  storageQuotaMb?: int32;
  createdAt: string;
  updatedAt?: string;
  privacy?: UserPrivacy;
  followers?: int32;
  following?: int32;
  postsCount?: int32;
  isFriend?: boolean;
  isOwner?: boolean;
  friendshipStatus?: string;
  friendRequestId?: string | null;
}

model UserPublic {
  id: string;
  username: string;
  displayName: string;
  bio?: string;
  personalInfo?: PersonalInfo;
  birthDate?: string | null;
  avatarPath?: string;
  avatar?: string | null;
  backgroundPath?: string;
  background?: string | null;
  accountStatus: string;
  role: string;
  createdAt: string;
  updatedAt?: string;
  followers?: int32;
  following?: int32;
  postsCount?: int32;
  viewer_context?: {
    is_owner: boolean;
    is_friend: boolean;
  };
  redacted_fields?: PrivacyField[];
  friendshipStatus?: string;
  friendRequestId?: string | null;
}

model UserMe extends UserPublic {
  email: string;
  phone?: string | null;
  storageQuotaMb?: int32;
  privacy?: UserPrivacy;
}

model LoginRequest {
  email: string;
  password: string;
}

model LoginResponse {
  access: string;
  refresh: string;
  tenant_slug: string;
}

model RegisterRequest {
  email: string;
  password: string;
  display_name: string;
  gender: Gender | string;
  role: Role;
  phone?: string;
  consent?: boolean;
  verification_media_asset_ids?: string[];
}

model RegisterResponse {
  id: string;
  email: string;
  username: string;
}

model VerifyOtpRequest {
  user_id: string;
  otp: string;
}

model VerifyOtpResponse {
  tenant_id: string;
  tenant_slug: string;
  status: string;
}

model ResendOtpRequest {
  user_id: string;
}

model RefreshTokenRequest {
  refresh: string;
}

model RefreshTokenResponse {
  access: string;
  refresh?: string;
}

model ForgotPasswordRequest {
  email: string;
}

model ResetPasswordRequest {
  user_id: string;
  otp: string;
  new_password: string;
}

model ChangePasswordMultipart {
  current_password: HttpPart<string>;
  new_password: HttpPart<string>;
}

model UploadAvatarResponse {
  avatar_url: string;
}

model UploadBackgroundResponse {
  background_url: string;
}

model UpdateProfileRequest {
  display_name?: string;
  username?: string;
  bio?: string;
  birth_date?: string;
}

model UpdatePrivacyRequest {
  default_visibility?: Visibility;
  overrides?: PrivacyOverride[];
}

model DeactivateMultipart {
  password: HttpPart<string>;
}

model ReactivationRequest {
  email: string;
}

model PostStats {
  reactions: int32;
  comments: int32;
  shares: int32;
}

model PostSummary {
  id: string;
  author: Author;
  content: string;
  mediaUrls: string[];
  media?: MediaAssetSummary[];
  stats: PostStats;
  userReaction: ReactionType | null;
  visibility: Visibility;
  postType: PostType;
  fieldId?: string;
  createdAt: string;
  updatedAt: string;
}

model Post {
  id: string;
  author: Author;
  content: string;
  mediaUrls: string[];
  media?: MediaAssetSummary[];
  stats: PostStats;
  userReaction: ReactionType | null;
  sharedPost: PostSummary | null;
  visibility: Visibility;
  postType: PostType;
  fieldId?: string;
  createdAt: string;
  updatedAt: string;
}

model FeedResponse {
  posts: PostSummary[];
  page: int32;
  page_size: int32;
  total: int32;
  total_pages: int32;
}

model UpdatePostRequest {
  content_text?: string;
  visibility?: Visibility;
  media_uploads?: string[];
}

model CreatePostRequest {
  content_text: string;
  visibility?: Visibility;
  post_type?: PostType;
  field_id?: string;
  media_asset_ids?: string[];
}

 

model CommentStats {
  reactions: int32;
  replies: int32;
}

model Comment {
  id: string;
  postId: string;
  author: Author;
  parentCommentId: string | null;
  content: string;
  mediaUrls: string[];
  stats: CommentStats;
  userReaction: ReactionType | null;
  createdAt: string;
  updatedAt: string;
}

model CommentResponse {
  comments: Comment[];
  page: int32;
  page_size: int32;
  total: int32;
  total_pages: int32;
}

model UpdateCommentRequest {
  content_text: string;
}

 

model CreateCommentRequest {
  post_id: string;
  content_text: string;
  media_asset_ids?: string[];
}

 

model ReplyRequest {
  post_id: string;
  content_text: string;
  media_asset_ids?: string[];
}

model MediaAssetSummary {
  id: string;
  type: "image" | "video" | "file";
  access: "public" | "private";
  cdn_url?: string;
  original_url?: string;
  thumbnail_url?: string;
  width?: int32;
  height?: int32;
  content_type?: string;
  size_bytes?: int64;
}

model MediaAsset extends MediaAssetSummary {
  status: "pending" | "ready" | "failed";
  createdAt: string;
}

model NameValueHeader {
  name: string;
  value: string;
}

model PresignedUploadInitRequest {
  filename: string;
  content_type: string;
  size_bytes: int64;
  checksum_sha256?: string;
  purpose?: "post" | "comment" | "avatar" | "background" | "kyc";
  access?: "public" | "private";
}

model PresignedUploadInitResponse {
  upload_id: string;
  asset_id: string;
  method: "PUT" | "POST";
  upload_url: string;
  headers: NameValueHeader[];
  expires_at: string;
}

model PresignedUploadCompleteRequest {
  etag?: string;
  size_bytes?: int64;
}

model ReactRequest {
  reaction: ReactionType;
}

model PostReaction {
  id: string;
  post_id: string;
  user_id: string;
  reaction: ReactionType;
  created_at: string;
}

model CommentReaction {
  id: string;
  comment_id: string;
  user_id: string;
  reaction: ReactionType;
  created_at: string;
}

model SharePostRequest {
  message?: string;
}

model ShareResponse {
  id: string;
  post_id: string;
  user_id: string;
  message?: string;
  created_at: string;
}

model Friend {
  id: string;
  user: Author;
  created_at: string;
}

model FriendRequest {
  id: string;
  requester: Author;
  addressee: Author;
  status: "PENDING" | "ACCEPTED" | "REJECTED" | "CANCELLED";
  created_at: string;
}

model CreateFriendRequestRequest {
  addressee_id?: string;
  addressee_username?: string;
}

model FriendshipStatus {
  is_friend: boolean;
  is_requested?: boolean;
  is_received?: boolean;
}

model Notification {
  id: string;
  type: NotificationType;
  actor: Author;
  targetId?: string;
  targetType?: "post" | "comment" | "friend_request";
  message: string;
  isRead: boolean;
  createdAt: string;
}

model UnreadCountResponse {
  unread_count: int32;
}

model SearchUsersResponse {
  users: UserPublic[];
  total: int32;
}

model ApiSuggestion {
  id: string;
  name: string;
  username?: string | null;
  avatar_path?: string | null;
  background_path?: string | null;
  role?: string;
  tags?: string[];
  connected_via?: string;
  target_name?: string;
  friend_status?: string;
  friend_request_id?: string | null;
  school?: string;
  class_name?: string;
  field?: string;
}

model RecommendationResponse {
  suggestions: ApiSuggestion[];
  total?: int32;
}

@doc("Nhóm API xác thực và quản lý phiên đăng nhập.")
@route("/auth")
@tag("Auth")
namespace Auth {
  @post
  @route("/login")
  @summary("Đăng nhập")
  @doc("Nhận email/mật khẩu và trả về access/refresh token + tenant_slug.")
  op login(@body body: LoginRequest): OkEnvelopeResponse<LoginResponse> | BadRequestEnvelopeResponse;

  @post
  @route("/register")
  @summary("Đăng ký tài khoản")
  @doc("Đăng ký bằng JSON. Nếu cần chứng thực người dùng, gửi verification_media_asset_ids (upload qua /media/uploads/public).")
  op register(
    @header contentType: "application/json",
    @body body: RegisterRequest
  ): OkEnvelopeResponse<RegisterResponse> | BadRequestEnvelopeResponse;

  @post
  @route("/verify-otp")
  @summary("Xác thực OTP")
  op verifyOtp(@body body: VerifyOtpRequest): OkEnvelopeResponse<VerifyOtpResponse> | BadRequestEnvelopeResponse;

  @post
  @route("/resend-otp")
  @summary("Gửi lại OTP")
  op resendOtp(@body body: ResendOtpRequest): OkEnvelopeResponse<{ message: string }> | BadRequestEnvelopeResponse;

  @post
  @route("/refresh")
  @summary("Làm mới access token")
  @doc("Đổi refresh token lấy access token mới.")
  op refresh(@body body: RefreshTokenRequest): OkEnvelopeResponse<RefreshTokenResponse> | BadRequestEnvelopeResponse;

  @post
  @route("/forgot-password")
  @summary("Quên mật khẩu")
  op forgotPassword(@body body: ForgotPasswordRequest): OkEnvelopeResponse<{ message: string; user_id?: string }> | BadRequestEnvelopeResponse;

  @post
  @route("/reset-password")
  @summary("Đặt lại mật khẩu")
  op resetPassword(@body body: ResetPasswordRequest): OkEnvelopeResponse<{ message: string }> | BadRequestEnvelopeResponse;

  @useAuth(BearerAuth)
  @post
  @route("/change-password")
  @summary("Đổi mật khẩu")
  @doc("Yêu cầu Bearer token + X-Tenant-Slug. Body dạng multipart.")
  op changePassword(
    ...AuthHeaders,
    @header contentType: "multipart/form-data",
    @multipartBody body: ChangePasswordMultipart
  ): OkEnvelopeResponse<{ message: string }> | BadRequestEnvelopeResponse | UnauthorizedEnvelopeResponse;

  @useAuth(BearerAuth)
  @post
  @route("/logout")
  @summary("Đăng xuất")
  op logout(...AuthHeaders): OkEnvelopeResponse<{ message: string }> | UnauthorizedEnvelopeResponse;

  @useAuth(BearerAuth)
  @get
  @route("/me")
  @summary("Lấy thông tin user hiện tại")
  op me(...AuthHeaders): OkEnvelopeResponse<UserMe> | UnauthorizedEnvelopeResponse;
}

@doc("Nhóm API quản lý hồ sơ người dùng hiện tại.")
@route("/users")
@tag("Users")
namespace Users {
  @useAuth(BearerAuth)
  @get
  @route("/me")
  @summary("Lấy profile của tôi")
  op getMe(...AuthHeaders): OkEnvelopeResponse<UserMe> | UnauthorizedEnvelopeResponse;

  @useAuth(BearerAuth)
  @patch
  @route("/me/profile")
  @summary("Cập nhật profile")
  op updateProfile(...AuthHeaders, @body body: UpdateProfileRequest): OkEnvelopeResponse<UserMe> | BadRequestEnvelopeResponse | UnauthorizedEnvelopeResponse;

  @useAuth(BearerAuth)
  @post
  @route("/me/avatar")
  @summary("Upload avatar")
  op uploadAvatar(
    ...AuthHeaders,
    @header contentType: "multipart/form-data",
    @multipartBody body: { file: HttpPart<Http.File> }
  ): OkEnvelopeResponse<UploadAvatarResponse> | BadRequestEnvelopeResponse | UnauthorizedEnvelopeResponse;

  @useAuth(BearerAuth)
  @post
  @route("/me/background")
  @summary("Upload ảnh nền")
  op uploadBackground(
    ...AuthHeaders,
    @header contentType: "multipart/form-data",
    @multipartBody body: { file: HttpPart<Http.File> }
  ): OkEnvelopeResponse<UploadBackgroundResponse> | BadRequestEnvelopeResponse | UnauthorizedEnvelopeResponse;

  @useAuth(BearerAuth)
  @patch
  @route("/me/privacy")
  @summary("Cập nhật quyền riêng tư")
  op updatePrivacy(...AuthHeaders, @body body: UpdatePrivacyRequest): OkEnvelopeResponse<UserPrivacy> | BadRequestEnvelopeResponse | UnauthorizedEnvelopeResponse;

  @useAuth(BearerAuth)
  @get
  @route("/me/privacy")
  @summary("Lấy cấu hình quyền riêng tư")
  op getPrivacy(...AuthHeaders): OkEnvelopeResponse<UserPrivacy> | UnauthorizedEnvelopeResponse;

  @useAuth(BearerAuth)
  @post
  @route("/me/deactivate")
  @summary("Vô hiệu hoá tài khoản")
  op deactivate(
    ...AuthHeaders,
    @header contentType: "multipart/form-data",
    @multipartBody body: DeactivateMultipart
  ): OkEnvelopeResponse<{ message?: string }> | BadRequestEnvelopeResponse | UnauthorizedEnvelopeResponse;

  @post
  @route("/me/reactivate")
  @summary("Kích hoạt lại tài khoản")
  op reactivate(@body body: ReactivationRequest): OkEnvelopeResponse<{ message: string }> | BadRequestEnvelopeResponse;

  @post
  @route("/me/reactivation-requests")
  @summary("Tạo yêu cầu kích hoạt lại")
  op createReactivationRequest(@body body: ReactivationRequest): OkEnvelopeResponse<{ message: string }> | BadRequestEnvelopeResponse;
}

@doc("Nhóm API feed/bảng tin.")
@tag("Feed")
namespace Feed {
  @useAuth(BearerAuth)
  @get
  @route("/feed")
  @summary("Lấy feed")
  @doc("Hỗ trợ phân trang và filter field_id/post_type.")
  op getFeed(
    ...AuthHeaders,
    @query page?: int32,
    @query("page_size") page_size?: int32,
    @query field_id?: string,
    @query post_type?: string
  ): OkEnvelopeResponse<FeedResponse> | UnauthorizedEnvelopeResponse;
}

@doc("Nhóm API bài viết (posts).")
@route("/posts")
@tag("Posts")
namespace Posts {
  @useAuth(BearerAuth)
  @get
  @route("/")
  @summary("Danh sách bài viết")
  op listPosts(...AuthHeaders, ...PaginationQuery): OkEnvelopeResponse<FeedResponse> | UnauthorizedEnvelopeResponse;

  @useAuth(BearerAuth)
  @get
  @route("/{postId}")
  @summary("Chi tiết bài viết")
  op getPost(...AuthHeaders, @path postId: string): OkEnvelopeResponse<Post> | UnauthorizedEnvelopeResponse | NotFoundEnvelopeResponse;

  @useAuth(BearerAuth)
  @post
  @route("/")
  @summary("Tạo bài viết")
  @doc("Tạo post bằng JSON và gắn media qua media_asset_ids (upload qua /media/uploads).")
  op createPost(
    ...AuthHeaders,
    @header contentType: "application/json",
    @body body: CreatePostRequest
  ): CreatedEnvelopeResponse<Post> | BadRequestEnvelopeResponse | UnauthorizedEnvelopeResponse;

  @useAuth(BearerAuth)
  @patch
  @route("/{postId}")
  @summary("Cập nhật bài viết")
  op updatePost(...AuthHeaders, @path postId: string, @body body: UpdatePostRequest): OkEnvelopeResponse<Post> | BadRequestEnvelopeResponse | UnauthorizedEnvelopeResponse | NotFoundEnvelopeResponse;

  @useAuth(BearerAuth)
  @delete
  @route("/{postId}")
  @summary("Xoá bài viết")
  op deletePost(...AuthHeaders, @path postId: string): OkEnvelopeResponse<{ message: string }> | UnauthorizedEnvelopeResponse | NotFoundEnvelopeResponse;

  @useAuth(BearerAuth)
  @get
  @route("/me")
  @summary("Danh sách bài viết của tôi")
  op getMyPosts(...AuthHeaders, ...PaginationQuery): OkEnvelopeResponse<FeedResponse> | UnauthorizedEnvelopeResponse;

  @useAuth(BearerAuth)
  @get
  @route("/users/{userId}")
  @summary("Danh sách bài viết theo user")
  op getPostsByUser(...AuthHeaders, @path userId: string, ...PaginationQuery): OkEnvelopeResponse<FeedResponse> | UnauthorizedEnvelopeResponse;

  @useAuth(BearerAuth)
  @get
  @route("/{postId}/comments")
  @summary("Danh sách comment của bài viết")
  op getPostComments(...AuthHeaders, @path postId: string, ...PaginationQuery): OkEnvelopeResponse<CommentResponse> | UnauthorizedEnvelopeResponse | NotFoundEnvelopeResponse;
}

@doc("Nhóm API bình luận (comments) và replies.")
@route("/comments")
@tag("Comments")
namespace Comments {
  @useAuth(BearerAuth)
  @post
  @route("/")
  @summary("Tạo comment")
  @doc("Tạo comment bằng JSON và gắn media qua media_asset_ids (upload qua /media/uploads).")
  op createComment(
    ...AuthHeaders,
    @header contentType: "application/json",
    @body body: CreateCommentRequest
  ): CreatedEnvelopeResponse<Comment> | BadRequestEnvelopeResponse | UnauthorizedEnvelopeResponse;

  @useAuth(BearerAuth)
  @patch
  @route("/{commentId}")
  @summary("Cập nhật comment")
  op updateComment(...AuthHeaders, @path commentId: string, @body body: UpdateCommentRequest): OkEnvelopeResponse<Comment> | BadRequestEnvelopeResponse | UnauthorizedEnvelopeResponse | NotFoundEnvelopeResponse;

  @useAuth(BearerAuth)
  @delete
  @route("/{commentId}")
  @summary("Xoá comment")
  op deleteComment(...AuthHeaders, @path commentId: string): OkEnvelopeResponse<{ message: string }> | UnauthorizedEnvelopeResponse | NotFoundEnvelopeResponse;

  @useAuth(BearerAuth)
  @post
  @route("/{commentId}/replies")
  @summary("Trả lời comment")
  @doc("Tạo reply bằng JSON và gắn media qua media_asset_ids (upload qua /media/uploads).")
  op replyToComment(
    ...AuthHeaders,
    @path commentId: string,
    @header contentType: "application/json",
    @body body: ReplyRequest
  ): CreatedEnvelopeResponse<Comment> | BadRequestEnvelopeResponse | UnauthorizedEnvelopeResponse | NotFoundEnvelopeResponse;
}

@doc("Nhóm API reactions (like/love/...).")
@tag("Reactions")
namespace Reactions {
  @useAuth(BearerAuth)
  @post
  @route("/posts/{postId}/reactions")
  @summary("React bài viết")
  op reactToPost(...AuthHeaders, @path postId: string, @body body: ReactRequest): OkEnvelopeResponse<PostReaction> | BadRequestEnvelopeResponse | UnauthorizedEnvelopeResponse | NotFoundEnvelopeResponse;

  @useAuth(BearerAuth)
  @delete
  @route("/posts/{postId}/reactions")
  @summary("Gỡ reaction bài viết")
  op unreactPost(...AuthHeaders, @path postId: string): OkEnvelopeResponse<{ message: string }> | UnauthorizedEnvelopeResponse | NotFoundEnvelopeResponse;

  @useAuth(BearerAuth)
  @post
  @route("/comments/{commentId}/reactions")
  @summary("React comment")
  op reactToComment(...AuthHeaders, @path commentId: string, @body body: ReactRequest): OkEnvelopeResponse<CommentReaction> | BadRequestEnvelopeResponse | UnauthorizedEnvelopeResponse | NotFoundEnvelopeResponse;

  @useAuth(BearerAuth)
  @delete
  @route("/comments/{commentId}/reactions")
  @summary("Gỡ reaction comment")
  op unreactComment(...AuthHeaders, @path commentId: string): OkEnvelopeResponse<{ message: string }> | UnauthorizedEnvelopeResponse | NotFoundEnvelopeResponse;
}

@doc("Nhóm API share/unshare bài viết.")
@tag("Shares")
namespace Shares {
  @useAuth(BearerAuth)
  @post
  @route("/posts/{postId}/share")
  @summary("Share bài viết")
  op sharePost(...AuthHeaders, @path postId: string, @body body?: SharePostRequest): OkEnvelopeResponse<ShareResponse> | BadRequestEnvelopeResponse | UnauthorizedEnvelopeResponse | NotFoundEnvelopeResponse;

  @useAuth(BearerAuth)
  @delete
  @route("/posts/{postId}/share")
  @summary("Gỡ share bài viết")
  op unsharePost(...AuthHeaders, @path postId: string): OkEnvelopeResponse<{ message: string }> | UnauthorizedEnvelopeResponse | NotFoundEnvelopeResponse;
}

@doc("Nhóm API bạn bè và lời mời kết bạn.")
@route("/friends")
@tag("Friends")
namespace Friends {
  @useAuth(BearerAuth)
  @get
  @route("/")
  @summary("Danh sách bạn bè")
  op listFriends(...AuthHeaders, ...PaginationQuery): OkEnvelopeResponse<{ friends: Friend[]; total: int32; page: int32; page_size: int32; total_pages: int32 }> | UnauthorizedEnvelopeResponse;

  @useAuth(BearerAuth)
  @post
  @route("/requests")
  @summary("Gửi lời mời kết bạn")
  op sendRequest(...AuthHeaders, @body body: CreateFriendRequestRequest): OkEnvelopeResponse<FriendRequest> | BadRequestEnvelopeResponse | UnauthorizedEnvelopeResponse;

  @useAuth(BearerAuth)
  @post
  @route("/requests/{requestId}/accept")
  @summary("Chấp nhận lời mời")
  op acceptRequest(...AuthHeaders, @path requestId: string): OkEnvelopeResponse<FriendRequest> | UnauthorizedEnvelopeResponse | NotFoundEnvelopeResponse;

  @useAuth(BearerAuth)
  @post
  @route("/requests/{requestId}/reject")
  @summary("Từ chối lời mời")
  op rejectRequest(...AuthHeaders, @path requestId: string): OkEnvelopeResponse<FriendRequest> | UnauthorizedEnvelopeResponse | NotFoundEnvelopeResponse;

  @useAuth(BearerAuth)
  @post
  @route("/requests/{requestId}/cancel")
  @summary("Huỷ lời mời")
  op cancelRequest(...AuthHeaders, @path requestId: string): OkEnvelopeResponse<FriendRequest> | UnauthorizedEnvelopeResponse | NotFoundEnvelopeResponse;

  @useAuth(BearerAuth)
  @get
  @route("/requests/incoming")
  @summary("Danh sách lời mời đến")
  op listIncomingRequests(...AuthHeaders, ...PaginationQuery): OkEnvelopeResponse<FriendRequest[]> | UnauthorizedEnvelopeResponse;

  @useAuth(BearerAuth)
  @get
  @route("/requests/outgoing")
  @summary("Danh sách lời mời đã gửi")
  op listOutgoingRequests(...AuthHeaders, ...PaginationQuery): OkEnvelopeResponse<FriendRequest[]> | UnauthorizedEnvelopeResponse;

  @useAuth(BearerAuth)
  @get
  @route("/check/{userId}")
  @summary("Kiểm tra trạng thái bạn bè")
  op checkFriendship(...AuthHeaders, @path userId: string): OkEnvelopeResponse<FriendshipStatus> | UnauthorizedEnvelopeResponse;

  @useAuth(BearerAuth)
  @delete
  @route("/{friendId}")
  @summary("Xoá bạn")
  op removeFriend(...AuthHeaders, @path friendId: string): OkEnvelopeResponse<{ message: string }> | UnauthorizedEnvelopeResponse | NotFoundEnvelopeResponse;
}

@doc("Nhóm API thông báo (notifications).")
@route("/notifications")
@tag("Notifications")
namespace Notifications {
  @useAuth(BearerAuth)
  @get
  @route("/")
  @summary("Danh sách thông báo")
  op listNotifications(...AuthHeaders, ...PaginationQuery): OkEnvelopeResponse<{ notifications: Notification[]; page: int32; page_size: int32; total: int32; total_pages: int32; unread_count: int32 }> | UnauthorizedEnvelopeResponse;

  @useAuth(BearerAuth)
  @post
  @route("/{notificationId}/read")
  @summary("Đánh dấu đã đọc")
  op markAsRead(...AuthHeaders, @path notificationId: string): OkEnvelopeResponse<{ message: string }> | UnauthorizedEnvelopeResponse | NotFoundEnvelopeResponse;

  @useAuth(BearerAuth)
  @post
  @route("/read-all")
  @summary("Đánh dấu tất cả đã đọc")
  op markAllAsRead(...AuthHeaders): OkEnvelopeResponse<{ message: string }> | UnauthorizedEnvelopeResponse;

  @useAuth(BearerAuth)
  @get
  @route("/unread-count")
  @summary("Đếm thông báo chưa đọc")
  op unreadCount(...AuthHeaders): OkEnvelopeResponse<UnreadCountResponse> | UnauthorizedEnvelopeResponse;

  @useAuth(BearerAuth)
  @delete
  @route("/{notificationId}")
  @summary("Xoá thông báo")
  op deleteNotification(...AuthHeaders, @path notificationId: string): OkEnvelopeResponse<{ message: string }> | UnauthorizedEnvelopeResponse | NotFoundEnvelopeResponse;
}

@doc("Nhóm API profile theo username.")
@tag("Profiles")
namespace Profiles {
  @useAuth(BearerAuth)
  @get
  @route("/profiles/{username}")
  @summary("Lấy profile theo username")
  op getProfile(...AuthHeaders, @path username: string): OkEnvelopeResponse<UserPublic> | UnauthorizedEnvelopeResponse | NotFoundEnvelopeResponse;
}

@doc("Nhóm API tìm kiếm.")
@tag("Search")
namespace Search {
  @useAuth(BearerAuth)
  @get
  @route("/search/users")
  @summary("Tìm kiếm user")
  op searchUsers(
    ...AuthHeaders,
    @query q: string,
    @query limit?: int32,
    @query page?: int32
  ): OkEnvelopeResponse<SearchUsersResponse> | UnauthorizedEnvelopeResponse;
}

@doc("Nhóm API gợi ý kết nối.")
@tag("Recommendations")
namespace Recommendations {
  @useAuth(BearerAuth)
  @get
  @route("/recommendations/suggestions")
  @summary("Lấy danh sách gợi ý")
  op suggestions(...AuthHeaders, @query filter: string): OkEnvelopeResponse<RecommendationResponse> | UnauthorizedEnvelopeResponse;
}

@doc("Nhóm API media.")
@tag("Media")
@route("/media")
namespace Media {
  @post
  @route("/uploads/public")
  @summary("Khởi tạo presigned upload (public)")
  @doc("Dành cho flow chưa đăng nhập (vd: KYC khi đăng ký). Client upload trực tiếp lên object storage.")
  op initPublicUpload(@body body: PresignedUploadInitRequest): CreatedEnvelopeResponse<PresignedUploadInitResponse> | BadRequestEnvelopeResponse;

  @post
  @route("/uploads/public/{uploadId}/complete")
  @summary("Hoàn tất upload (public)")
  @doc("Xác nhận upload hoàn thành cho flow chưa đăng nhập (vd: KYC).")
  op completePublicUpload(
    @path uploadId: string,
    @body body: PresignedUploadCompleteRequest
  ): OkEnvelopeResponse<MediaAsset> | BadRequestEnvelopeResponse | NotFoundEnvelopeResponse;

  @useAuth(BearerAuth)
  @post
  @route("/uploads")
  @summary("Khởi tạo presigned upload")
  @doc("Trả về upload_url + headers để client upload trực tiếp lên object storage. Sau đó gọi complete để xác nhận.")
  op initUpload(...AuthHeaders, @body body: PresignedUploadInitRequest): CreatedEnvelopeResponse<PresignedUploadInitResponse> | BadRequestEnvelopeResponse | UnauthorizedEnvelopeResponse;

  @useAuth(BearerAuth)
  @post
  @route("/uploads/{uploadId}/complete")
  @summary("Hoàn tất upload")
  @doc("Xác nhận upload hoàn thành và trả MediaAsset. Backend có thể xử lý thumbnail/variants async.")
  op completeUpload(
    ...AuthHeaders,
    @path uploadId: string,
    @body body: PresignedUploadCompleteRequest
  ): OkEnvelopeResponse<MediaAsset> | BadRequestEnvelopeResponse | UnauthorizedEnvelopeResponse | NotFoundEnvelopeResponse;

  @useAuth(BearerAuth)
  @get
  @route("/stream")
  @summary("Stream media")
  @doc("Tải media theo R2 key (query path). UI có thể thêm access_token trên query khi dùng trực tiếp trong browser.")
  op stream(
    ...AuthHeaders,
    @query path: string,
    @query access_token?: string
  ): {@statusCode statusCode: 200; @body body: bytes;} | UnauthorizedEnvelopeResponse;

  @useAuth(BearerAuth)
  @get
  @route("/assets/{assetId}")
  @summary("Lấy metadata media asset")
  op getAsset(...AuthHeaders, @path assetId: string): OkEnvelopeResponse<MediaAsset> | UnauthorizedEnvelopeResponse | NotFoundEnvelopeResponse;

  @useAuth(BearerAuth)
  @post
  @route("/assets/{assetId}/download-url")
  @summary("Lấy signed download URL")
  @doc("Trả URL tạm thời để dùng trong <img src> hoặc download qua CDN mà không cần token query.")
  op getSignedDownloadUrl(
    ...AuthHeaders,
    @path assetId: string,
    @body body: { expires_in_seconds?: int32 }
  ): OkEnvelopeResponse<{ url: string; expires_at: string }> | UnauthorizedEnvelopeResponse | NotFoundEnvelopeResponse;
}

}