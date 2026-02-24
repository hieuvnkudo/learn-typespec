import "@typespec/http";
import "@typespec/openapi";

using Http;
using TypeSpec.OpenAPI;

@doc("Message microservice contract (baseURL riêng).")
@service(#{ title: "Etechs Message Service" })
@server("https://example.com", "Message service base (UI config maps to /api-message or http://localhost:8001)")
namespace MessageService {
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

  model MessageAuthHeaders {
    @header("Authorization")
    authorization: string;

    @header("X-Tenant-Slug")
    tenant_slug: string;
  }

  model Room {
    id: string;
    type: string;
    name: string;
    created_at: string;
  }

  model LastMessage {
    id: string;
    sender_id: string;
    created_at: string;
    snippet: string;
  }

  model RoomUser {
    room_id: string;
    role: string | null;
    name: string;
    last_message: LastMessage | null;
    unread: int32;
  }

  model Reaction {
    id: string;
    user_id: string;
    emoji: string;
    created_at: string;
  }

  model Message {
    id: string;
    room_id: string;
    sender_id: string;
    ciphertext: string;
    created_at: string;
    attachment_url?: string | null;
    attachment_urls?: string[] | null;
    pinned?: boolean;
    reactions?: Reaction[];
    encrypted_key?: string;
    encrypted_key_recipient?: string;
    encrypted_key_sender?: string;
    iv?: string;
  }

  model CreateRoomRequest {
    name: string;
    type: string;
    member_ids: string[];
    creator_id: string;
  }

  model PostMessageRequest {
    room_id: string;
    sender_id: string;
    content: string;
    encrypted_key?: string;
    iv?: string;
  }

  model PostMessageResponse {
    id: string;
    room_id: string;
    sender_id: string;
    ciphertext: string;
    created_at: string;
    encrypted_key?: string;
    iv?: string;
  }

  model AddMemberRequest {
    user_id: string;
  }

  model SetRoleRequest {
    role: string;
  }

  model RoomDetails {
    id: string;
    type: string;
    name: string;
    created_at: string;
  }

  model DisplayNameRequest {
    display_name: string;
  }

  model DisplayNameResponse {
    room_id: string;
    user_id: string;
    display_name: string;
  }

  model PublicKeyRequest {
    user_id: string;
    public_key: string;
  }

  model PublicKeyResponse {
    user_id: string;
    public_key: string;
    updated_at?: string;
  }

  model MemberPublicKeysResponse {
    members: {
      user_id: string;
      public_key?: string;
      display_name?: string;
    }[];
  }

  model E2EEBackupRequest {
    ciphertext: string;
    salt: string;
    iv: string;
    iterations: int32;
    algo: string;
    version?: string;
  }

  @route("/api")
  @tag("Message")
  namespace Api {
    @useAuth(BearerAuth)
    @get
    @route("/users/{userId}/rooms")
    op roomsForUser(...MessageAuthHeaders, @path userId: string): OkEnvelopeResponse<RoomUser[]> | UnauthorizedEnvelopeResponse;

    @useAuth(BearerAuth)
    @post
    @route("/rooms/")
    op createRoom(...MessageAuthHeaders, @body body: CreateRoomRequest): CreatedEnvelopeResponse<Room> | BadRequestEnvelopeResponse | UnauthorizedEnvelopeResponse;

    @useAuth(BearerAuth)
    @get
    @route("/rooms/{roomId}/messages")
    op roomMessages(...MessageAuthHeaders, @path roomId: string): OkEnvelopeResponse<Message[]> | UnauthorizedEnvelopeResponse | NotFoundEnvelopeResponse;

    @useAuth(BearerAuth)
    @post
    @route("/rooms/{roomId}/messages")
    op postMessage(...MessageAuthHeaders, @path roomId: string, @body body: PostMessageRequest): CreatedEnvelopeResponse<PostMessageResponse> | BadRequestEnvelopeResponse | UnauthorizedEnvelopeResponse | NotFoundEnvelopeResponse;

    @useAuth(BearerAuth)
    @post
    @route("/rooms/{roomId}/upload")
    op upload(
      ...MessageAuthHeaders,
      @path roomId: string,
      @query sender_id?: string,
      @query client_id?: string,
      @header contentType: "multipart/form-data",
      @multipartBody body: {
        files: HttpPart<Http.File[]>;
        content?: HttpPart<string>;
      }
    ): OkEnvelopeResponse<string> | BadRequestEnvelopeResponse | UnauthorizedEnvelopeResponse | NotFoundEnvelopeResponse;

    @useAuth(BearerAuth)
    @delete
    @route("/messages/{messageId}")
    op deleteMessage(
      ...MessageAuthHeaders,
      @path messageId: string,
      @query user_id?: string,
      @query hard?: boolean
    ): OkEnvelopeResponse<string> | UnauthorizedEnvelopeResponse | NotFoundEnvelopeResponse;

    @useAuth(BearerAuth)
    @post
    @route("/messages/{messageId}/reactions")
    op addReaction(
      ...MessageAuthHeaders,
      @path messageId: string,
      @body body: { emoji: string; user_id: string }
    ): OkEnvelopeResponse<string> | BadRequestEnvelopeResponse | UnauthorizedEnvelopeResponse | NotFoundEnvelopeResponse;

    @useAuth(BearerAuth)
    @delete
    @route("/messages/{messageId}/reactions")
    op removeReaction(
      ...MessageAuthHeaders,
      @path messageId: string,
      @query user_id: string,
      @query emoji: string
    ): OkEnvelopeResponse<string> | UnauthorizedEnvelopeResponse | NotFoundEnvelopeResponse;

    @useAuth(BearerAuth)
    @post
    @route("/messages/{messageId}/pin")
    op pinMessage(...MessageAuthHeaders, @path messageId: string, @query pin?: boolean): OkEnvelopeResponse<string> | UnauthorizedEnvelopeResponse | NotFoundEnvelopeResponse;

    @useAuth(BearerAuth)
    @post
    @route("/messages/{messageId}/unpin")
    op unpinMessage(...MessageAuthHeaders, @path messageId: string): OkEnvelopeResponse<string> | UnauthorizedEnvelopeResponse | NotFoundEnvelopeResponse;

    @useAuth(BearerAuth)
    @get
    @route("/rooms/{roomId}/pinned")
    op pinnedMessages(...MessageAuthHeaders, @path roomId: string): OkEnvelopeResponse<string> | UnauthorizedEnvelopeResponse | NotFoundEnvelopeResponse;

    @useAuth(BearerAuth)
    @get
    @route("/messages/{messageId}/readers")
    op messageReaders(...MessageAuthHeaders, @path messageId: string): OkEnvelopeResponse<string> | UnauthorizedEnvelopeResponse | NotFoundEnvelopeResponse;

    @useAuth(BearerAuth)
    @get
    @route("/rooms/{roomId}/search")
    op searchRoom(...MessageAuthHeaders, @path roomId: string, @query q: string, @query limit?: int32): OkEnvelopeResponse<string> | UnauthorizedEnvelopeResponse | NotFoundEnvelopeResponse;

    @useAuth(BearerAuth)
    @post
    @route("/rooms/{roomId}/read")
    op markRead(...MessageAuthHeaders, @path roomId: string, @query user_id: string): OkEnvelopeResponse<string> | UnauthorizedEnvelopeResponse | NotFoundEnvelopeResponse;

    @useAuth(BearerAuth)
    @post
    @route("/rooms/{roomId}/members")
    op addMember(...MessageAuthHeaders, @path roomId: string, @body body: AddMemberRequest): OkEnvelopeResponse<string> | BadRequestEnvelopeResponse | UnauthorizedEnvelopeResponse | NotFoundEnvelopeResponse;

    @useAuth(BearerAuth)
    @delete
    @route("/rooms/{roomId}/members/{userId}")
    op removeMember(...MessageAuthHeaders, @path roomId: string, @path userId: string): OkEnvelopeResponse<string> | UnauthorizedEnvelopeResponse | NotFoundEnvelopeResponse;

    @useAuth(BearerAuth)
    @post
    @route("/rooms/{roomId}/members/{userId}/role")
    op setRole(...MessageAuthHeaders, @path roomId: string, @path userId: string, @body body: SetRoleRequest): OkEnvelopeResponse<string> | BadRequestEnvelopeResponse | UnauthorizedEnvelopeResponse | NotFoundEnvelopeResponse;

    @useAuth(BearerAuth)
    @get
    @route("/rooms/{roomId}")
    op getRoom(...MessageAuthHeaders, @path roomId: string): OkEnvelopeResponse<RoomDetails> | UnauthorizedEnvelopeResponse | NotFoundEnvelopeResponse;

    @useAuth(BearerAuth)
    @delete
    @route("/rooms/{roomId}")
    op deleteRoom(...MessageAuthHeaders, @path roomId: string, @query hard?: boolean, @query user_id?: string): OkEnvelopeResponse<string> | UnauthorizedEnvelopeResponse | NotFoundEnvelopeResponse;

    @useAuth(BearerAuth)
    @post
    @route("/rooms/{roomId}/members/{userId}/display_name")
    op setDisplayName(
      ...MessageAuthHeaders,
      @path roomId: string,
      @path userId: string,
      @body body: DisplayNameRequest
    ): OkEnvelopeResponse<DisplayNameResponse> | BadRequestEnvelopeResponse | UnauthorizedEnvelopeResponse | NotFoundEnvelopeResponse;

    @useAuth(BearerAuth)
    @get
    @route("/users/{userId}/public_key")
    op getPublicKey(...MessageAuthHeaders, @path userId: string): OkEnvelopeResponse<PublicKeyResponse> | UnauthorizedEnvelopeResponse | NotFoundEnvelopeResponse;

    @useAuth(BearerAuth)
    @post
    @route("/users/public_key")
    op setPublicKey(...MessageAuthHeaders, @body body: PublicKeyRequest): OkEnvelopeResponse<PublicKeyResponse> | BadRequestEnvelopeResponse | UnauthorizedEnvelopeResponse;

    @useAuth(BearerAuth)
    @put
    @route("/users/public_key")
    op updatePublicKey(...MessageAuthHeaders, @body body: PublicKeyRequest): OkEnvelopeResponse<PublicKeyResponse> | BadRequestEnvelopeResponse | UnauthorizedEnvelopeResponse;

    @useAuth(BearerAuth)
    @get
    @route("/rooms/{roomId}/members/public_keys")
    op roomMemberPublicKeys(...MessageAuthHeaders, @path roomId: string): OkEnvelopeResponse<MemberPublicKeysResponse> | UnauthorizedEnvelopeResponse | NotFoundEnvelopeResponse;

    @useAuth(BearerAuth)
    @get
    @route("/rooms/dm")
    op getDMRoom(...MessageAuthHeaders, @query user_a?: string, @query user_b?: string): OkEnvelopeResponse<unknown> | UnauthorizedEnvelopeResponse;

    @useAuth(BearerAuth)
    @post
    @route("/users/{userId}/e2ee_backup")
    op backupKey(...MessageAuthHeaders, @path userId: string, @body body: E2EEBackupRequest): OkEnvelopeResponse<unknown> | BadRequestEnvelopeResponse | UnauthorizedEnvelopeResponse;

    @useAuth(BearerAuth)
    @get
    @route("/users/{userId}/e2ee_backup")
    op getBackup(...MessageAuthHeaders, @path userId: string): OkEnvelopeResponse<unknown> | UnauthorizedEnvelopeResponse | NotFoundEnvelopeResponse;

    @useAuth(BearerAuth)
    @delete
    @route("/users/{userId}/e2ee_backup")
    op deleteBackup(...MessageAuthHeaders, @path userId: string): OkEnvelopeResponse<unknown> | UnauthorizedEnvelopeResponse | NotFoundEnvelopeResponse;
  }
}
