<%@ page contentType="text/html;charset=UTF-8" language="java" %>
<html>
<head>
  <title>404 Error</title>
  <link href="https://fonts.googleapis.com/css?family=Roboto:700" rel="stylesheet">
  <style>
    h1 {
      font-size: 80px;
      font-weight: 800;
      text-align: center;
      font-family: 'Roboto', sans-serif;
    }
    h2 {
      font-size: 25px;
      text-align: center;
      font-family: 'Roboto', sans-serif;
      margin-top: -40px;
    }
    p {
      text-align: center;
      font-family: 'Roboto', sans-serif;
      font-size: 12px;
    }
    .container {
      width: 300px;
      margin: 0 auto;
      margin-top: 15%;
    }
  </style>
</head>
<body>
  <div class="container">
    <h1>404</h1>
    <h2>Page Not Found</h2>
    <p>
      The page you are looking for doesn't exist or another error occurred.<br>
      Go to <a href="${pageContext.request.contextPath}/login.htm">login page</a>.
    </p>
  </div>
</body>
</html>



