# Uber API Integration Steps

## Step 1: Select Scopes

Select the scopes from the above list. Your selection will be saved for later.

## Step 2: Add Asymmetric Keys and Download Private Key

1. Click on the **Setup Tab** on the Left navigation
2. Go to **Authentication using Client Secret** section
3. Click on **Add Asymmetric Key** button

A file containing a generated private key will get downloaded. This key is required in the following steps. Ensure to safely store this file as this cannot be retrieved.

## Step 3: Prepare JWT Assertion

Gather claim data for header and payload. Let's represent the claim in a JSON format, the first section is header, the second section is payload.

**Header:**
```json
{
  "alg": "RS256",
  "typ": "JWT",
  "kid": "<KEY_UUID_FROM_DOWNLOADED_FILE>"
}
```

**Payload:**
```json
{
  "iss": "wcNEp6qTL86jOPBtKVpkJv5IV_WRuj3U",
  "sub": "wcNEp6qTL86jOPBtKVpkJv5IV_WRuj3U",
  "aud": "auth.uber.com",
  "jti": "<RANDOM_GENERATED_UUID>",
  "exp": "<TOKEN_EXPIRATION_IN_EPOCH>"
}
```

- `iss` / `sub`: Application ID (`wcNEp6qTL86jOPBtKVpkJv5IV_WRuj3U`)
- `aud`: Always `auth.uber.com`
- `jti`: Random UUID per request
- `exp`: Token expiration in epoch seconds

## Step 4: Generate Signature

There are many libraries available to generate signature with your private key, just pick the one you like for your target programming language. You can also give it a try at https://jwt.io/

The generated signature would look similar to the below one. This is essentially `base64UrlEncoded(header) + "." + base64UrlEncoded(payload) + "." + signature`:

```
eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiYWRtaW4iOnRydWUsImlhdCI6MTUxNjIzOTAyMn0.NHVaYe26MbtOYhSKkoKYdFVomg4i8ZJd8_-RU8VNbftc4TSMb4bXP3l3YlNWACwyXPGffz5aXHc6lty1Y2t4SWRqGteragsVdZufDn5BlnJl9pdR_kdVFUsra2rWKEofkZeIC4yWytE58sMIihvo9H1ScmmVwBcQP6XETqYd0aSHp1gOa9RdUPDvoXQ5oqygTqVtxaDr6wUFKrKItgBMzWIdNZ6y7O9E0DhEPTbE9rfBo6KTFsHAZnMg4k68CDp2woYIaXbmYTWcvbzIuHO7_37GT79XdIwkm95QJ7hYC9RiwrV7mesbY4PAahERJawntho0my942XheVLmGwLMBkQ
```

## Step 5: Generate Access Token

Use the below endpoint to generate the access token.

**Request:**
```bash
curl -X POST "https://auth.uber.com/oauth/v2/token" \
  -d 'scope=<SPACE_DELIMITED_LIST_OF_SCOPES>' \
  -d 'grant_type=client_credentials' \
  -d 'client_assertion=<JWT_ASSERTION_GENERATED>' \
  -d 'client_assertion_type="urn:ietf:params:oauth:client-assertion-type:jwt-bearer"'
```

**Response:**
```json
{
  "access_token": "<ACCESS_TOKEN>",
  "token_type": "Bearer",
  "expires_in": "<EXPIRY_IN_EPOCH>",
  "scope": "<SPACE_DELIMITED_LIST_OF_SCOPES>"
}
```

## Step 6: Use Access Token

Pass the `<ACCESS_TOKEN>` returned in the previous step as a bearer token in the Authorization header, or pass it as a query parameter in the URL.

**Example (header):**
```bash
curl -H "Authorization: Bearer <ACCESS_TOKEN>" \
  "https://api.uber.com/v1.2/products?latitude=37.7759792&longitude=-122.41823"
```
