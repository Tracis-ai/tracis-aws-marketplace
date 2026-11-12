function handler(event) {
  var request = event.request;
  var uri = request.uri;

  if (request.method !== "GET" && request.method !== "HEAD") {
    return request;
  }

  if (uri === "/api" || uri.indexOf("/api/") === 0) {
    return request;
  }

  if (uri.indexOf(".") === -1) {
    request.uri = "/index.html";
  }

  return request;
}
