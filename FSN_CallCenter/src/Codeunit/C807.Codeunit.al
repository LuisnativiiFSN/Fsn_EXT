codeunit 50055 "C807 CCONECTION"
{
    SingleInstance = true;
    trigger OnRun()
    begin

    end;

    var
        myInt: Integer;

    procedure Post(Uri: Text; request: HttpRequestMessage): JsonObject;
    var
        client: HttpClient;
        response: HttpResponseMessage;
        content: HttpContent;
        status: Integer;
        res: Text;
        jResponse: JsonObject;
    begin
        request.Method := 'POST';
        request.SetRequestUri(uri);
        client.Send(request, response);
        content := response.Content;
        status := response.HttpStatusCode;
        content.ReadAs(res);
        jResponse.ReadFrom(res);
        exit(jResponse);
    end;
}