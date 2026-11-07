/* Linux loopback HTTP/1.1 transport for the web examples. One request per connection. */
#include <arpa/inet.h>
#include <errno.h>
#include <netinet/in.h>
#include <stdio.h>
#include <string.h>
#include <strings.h>
#include <sys/socket.h>
#include <sys/time.h>
#include <unistd.h>

static char dg_data[16385];
static char *dg_method_begin, *dg_target_begin, *dg_headers_begin, *dg_body_begin;
static size_t dg_method_size, dg_target_size, dg_body_size;

static int dg_send_all(int client, const void *bytes, size_t len) {
    const char *p = bytes;
    while (len) {
        ssize_t n = send(client, p, len, MSG_NOSIGNAL);
        if (n < 0 && errno == EINTR) continue;
        if (n <= 0) return 0;
        p += n;
        len -= (size_t)n;
    }
    return 1;
}

static int32_t dg_listen(int32_t port) {
    int fd = socket(AF_INET, SOCK_STREAM, 0);
    if (fd < 0) return -1;
    int reuse = 1;
    struct sockaddr_in addr = {
        .sin_family = AF_INET,
        .sin_port = htons((uint16_t)port),
        .sin_addr.s_addr = htonl(INADDR_LOOPBACK)
    };
    if (setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &reuse, sizeof reuse) ||
        bind(fd, (struct sockaddr *)&addr, sizeof addr) || listen(fd, 64)) {
        close(fd);
        return -1;
    }
    return fd;
}

static int dg_read_more(int client, size_t *used) {
    size_t remaining = sizeof dg_data - 1 - *used;
    if (!remaining) return 0;
    ssize_t n;
    do { n = recv(client, dg_data + *used, remaining, 0); }
    while (n < 0 && errno == EINTR);
    if (n <= 0) return 0;
    *used += (size_t)n;
    dg_data[*used] = '\0';
    return 1;
}

static int dg_header_name(const char *line, const char *colon, const void *key, size_t size) {
    return (size_t)(colon - line) == size && !strncasecmp(line, key, size);
}

static int dg_parse_request(int client) {
    size_t used = 0;
    char *end = NULL;
    while (!end) {
        if (!dg_read_more(client, &used)) return 0;
        end = strstr(dg_data, "\r\n\r\n");
    }
    if (end - dg_data > 8192) return 0;
    char *line_end = strstr(dg_data, "\r\n");
    char *method_end = memchr(dg_data, ' ', (size_t)(line_end - dg_data));
    if (!method_end || method_end == dg_data) return 0;
    char *target = method_end + 1;
    char *target_end = memchr(target, ' ', (size_t)(line_end - target));
    if (!target_end || target_end == target || *target != '/' ||
        line_end - target_end != 9 || memcmp(target_end + 1, "HTTP/1.1", 8)) return 0;

    dg_method_begin = dg_data;
    dg_method_size = (size_t)(method_end - dg_data);
    dg_target_begin = target;
    dg_target_size = (size_t)(target_end - target);
    dg_headers_begin = line_end + 2;
    dg_body_begin = end + 4;
    dg_body_size = 0;
    int saw_length = 0;

    for (char *line = dg_headers_begin; line < end; line = line_end + 2) {
        line_end = strstr(line, "\r\n");
        char *colon = memchr(line, ':', (size_t)(line_end - line));
        if (!colon || colon == line) return 0;
        if (dg_header_name(line, colon, "Transfer-Encoding", 17)) return 0;
        if (!dg_header_name(line, colon, "Content-Length", 14)) continue;
        if (saw_length++) return 0;
        char *p = colon + 1;
        while (p < line_end && (*p == ' ' || *p == '\t')) p++;
        if (p == line_end) return 0;
        for (; p < line_end && *p >= '0' && *p <= '9'; p++) {
            dg_body_size = dg_body_size * 10 + (size_t)(*p - '0');
            if (dg_body_size > 4096) return 0;
        }
        while (p < line_end && (*p == ' ' || *p == '\t')) p++;
        if (p != line_end) return 0;
    }
    while (used < (size_t)(dg_body_begin - dg_data) + dg_body_size) {
        if (!dg_read_more(client, &used)) return 0;
    }
    return 1;
}

static int32_t dg_accept(int32_t listener) {
    int client = accept(listener, NULL, NULL);
    if (client < 0) return errno == EINTR ? -1 : -2;
    struct timeval timeout = {.tv_sec = 2};
    if (setsockopt(client, SOL_SOCKET, SO_RCVTIMEO, &timeout, sizeof timeout) ||
        setsockopt(client, SOL_SOCKET, SO_SNDTIMEO, &timeout, sizeof timeout) ||
        !dg_parse_request(client)) {
        const char bad[] = "HTTP/1.1 400 Bad Request\r\nContent-Length: 0\r\nConnection: close\r\n\r\n";
        dg_send_all(client, bad, sizeof bad - 1);
        close(client);
        return -1;
    }
    return client;
}

static void dg_request(gs_rref method, gs_rref target, gs_rref body) {
    gs_bld_append(method, dg_method_begin, dg_method_size);
    gs_bld_append(target, dg_target_begin, dg_target_size);
    gs_bld_append(body, dg_body_begin, dg_body_size);
}

static void dg_header(sl_u8 key, gs_rref out) {
    for (char *line = dg_headers_begin; line < dg_body_begin - 4;) {
        char *end = strstr(line, "\r\n");
        char *colon = memchr(line, ':', (size_t)(end - line));
        if (dg_header_name(line, colon, key.data, (size_t)key.len)) {
            char *value = colon + 1;
            while (value < end && (*value == ' ' || *value == '\t')) value++;
            while (end > value && (end[-1] == ' ' || end[-1] == '\t')) end--;
            gs_bld_append(out, value, (size_t)(end - value));
            return;
        }
        line = end + 2;
    }
}

static void dg_reply(int32_t client, int32_t status, sl_u8 mime, sl_u8 body,
                     sl_u8 request_id, sl_u8 stages, sl_u8 location) {
    const char *reason = status == 200 ? "OK" : status == 201 ? "Created" :
                         status == 400 ? "Bad Request" : "Not Found";
    char header[1024];
    int n = snprintf(header, sizeof header,
        "HTTP/1.1 %d %s\r\nContent-Length: %lld\r\nConnection: close\r\n"
        "%s%.*s%s%s%.*s%s%s%.*s%s%s%.*s%s\r\n",
        status, reason, (long long)body.len,
        mime.len ? "Content-Type: " : "", (int)mime.len, mime.len ? (char *)mime.data : "", mime.len ? "\r\n" : "",
        request_id.len ? "X-Request-Id: " : "", (int)request_id.len, request_id.len ? (char *)request_id.data : "", request_id.len ? "\r\n" : "",
        stages.len ? "X-Stages: " : "", (int)stages.len, stages.len ? (char *)stages.data : "", stages.len ? "\r\n" : "",
        location.len ? "Location: " : "", (int)location.len, location.len ? (char *)location.data : "", location.len ? "\r\n" : "");
    if (n > 0 && (size_t)n < sizeof header && dg_send_all(client, header, (size_t)n))
        dg_send_all(client, body.data, (size_t)body.len);
    close(client);
}

static void dg_method_not_allowed(int32_t client, sl_u8 allow) {
    char header[128];
    int n = snprintf(header, sizeof header,
        "HTTP/1.1 405 Method Not Allowed\r\nAllow: %.*s\r\nContent-Length: 0\r\nConnection: close\r\n\r\n",
        (int)allow.len, (const char *)allow.data);
    if (n > 0 && (size_t)n < sizeof header) dg_send_all(client, header, (size_t)n);
    close(client);
}
