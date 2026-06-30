# Build stage
FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src

COPY ZoSdk.csproj ./
RUN dotnet restore ZoSdk.csproj

COPY . .
RUN dotnet publish ZoSdk.csproj -c Release -r linux-x64 --no-self-contained -o /app

# Runtime stage
# aspnet image includes ASP.NET Core runtime and the libc/libssl deps the native ziti4dotnet.so needs.
FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS runtime
WORKDIR /app

# The OpenZiti.NET.native package ships a prebuilt ziti4dotnet.so for linux-x64 inside the NuGet.
# dotnet publish copies it into the output folder as a native asset; it lands at:
#   /app/runtimes/linux-x64/native/libziti4dotnet.so
# The CLR DllImport resolver finds it via the runtimes/ subfolder automatically when
# DOTNET_BUNDLE_EXTRACT_BASE_DIR / default probing is in effect.
# If the .so is not found at runtime, set LD_LIBRARY_PATH=/app/runtimes/linux-x64/native.
ENV LD_LIBRARY_PATH=/app/runtimes/linux-x64/native

COPY --from=build /app .

ENV ZITI_IDENTITY=/ziti/id.json
ENV ZITI_SERVICE=""
ENV SELF_LANG=cs

ENTRYPOINT ["dotnet", "/app/zosdk.dll"]
# Usage: docker run zo-sdk-cs echo server
#        docker run zo-sdk-cs echo client
#        docker run zo-sdk-cs http server
#        docker run zo-sdk-cs http client
CMD ["--help"]
