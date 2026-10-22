# Chỉ chứa runtime: code đã được build sẵn trên máy (dotnet publish) nên VPS nhỏ cũng chạy nhẹ.
FROM mcr.microsoft.com/dotnet/aspnet:10.0
WORKDIR /app
COPY app/ .
USER $APP_UID
ENTRYPOINT ["dotnet", "BaKhi_API.dll"]
