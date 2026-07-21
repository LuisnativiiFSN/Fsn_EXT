/// <summary>
/// Codeunit DTE API Connection (ID 50050).
/// </summary>
codeunit 50050 "DTE API Connection"
{
    SingleInstance = true;

    #region [Methods]
    /// <summary>
    /// Method to get the invoice from the DTE API.
    /// </summary>
    /// <param name="Uri">Text.</param>
    /// <param name="Header">JsonObject.</param>
    /// <param name="Body">jsonObject.</param>
    /// <returns>Return value of type Text.</returns>
    procedure Get(Uri: Text; request: HttpRequestMessage): JsonObject;
    var
        client: HttpClient;
        response: HttpResponseMessage;
        content: HttpContent;
        res: Text;
        json: JsonObject;
    begin
        request.Method := 'GET';
        request.SetRequestUri(uri);
        client.Send(request, response);

        content := response.Content;
        content.ReadAs(res);

        json.Add('status', response.HttpStatusCode);
        json.Add('body', res);

        exit(json);
    end;

    procedure Post()
    begin

    end;

    /// <summary>
    /// Method to send a POST request to the DTE API.
    /// </summary>
    /// <param name="Uri">Text</param>
    /// <param name="request">HttpRequestMessage</param>
    /// <returns>Return Response body conntent</returns>
    procedure Post(Uri: Text; request: HttpRequestMessage): JsonObject;
    var
        client: HttpClient;
        contentHeader: HttpHeaders;
        response: HttpResponseMessage;
        content: HttpContent;
        status: Integer;
        res: Text;
        jResponse: JsonObject;
        json: JsonObject;
    begin
        request.Method := 'POST';
        request.SetRequestUri(uri);

        if client.Send(request, response) then begin
            content := response.Content;
            status := response.HttpStatusCode;
            content.ReadAs(res);

            IF jResponse.ReadFrom(res) THEN;

            json.Add('status', status);
            json.Add('body', jResponse);

            exit(json);
        end else begin
            json.Add('status', response.HttpStatusCode);
            json.Add('body', 'Error');
            exit(json);
        end;
    end;
    #endregion
}
