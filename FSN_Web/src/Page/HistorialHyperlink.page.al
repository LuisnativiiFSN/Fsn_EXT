page 50108 "FSN Historico HyperLink"
{
    Caption = 'Historico de pedidos';
    Editable = true;
    PageType = Card;
    UsageCategory = Administration;

    layout
    {
        area(content)
        {
            // Grupo para el campo URL (puedes ponerlo arriba o en un FastTab)
            group(Control5)
            {
                ShowCaption = false;
            }
            // Grupo exclusivo para el usercontrol, sin caption
            usercontrol(Response; "SPLN Demo")
            {
                ApplicationArea = All;

                trigger ControlAddInReady(callbackUrl: Text)
                begin
                    CurrPage.Response.Navigate(URL);
                end;

                trigger HistoricoVenta(array: JsonObject)
                begin
                    array.WriteTo(XMLRequest);
                    RequestID := 'CREATEORDER';
                    FSNUtility.InvokeGlobalChannel(XMLRequest, XMLResponse, RequestID, PosMenuLineTemp, Processed, MsgResult);
                    IF XMLResponse = 'OK' then
                        CurrPage.Close();
                end;

                trigger RecibirDatos(array: JsonObject)
                begin
                    CalPro.InsertCliente(array);
                    array.WriteTo(XMLRequest);
                    CurrPage.Close();
                end;

                trigger CrearCliente(array: JsonObject)
                begin
                    CalPro.ValidateCustome(array);
                    CurrPage.Close();
                end;
            }
        }
    }
    var
        URL: Text;
        POSGUI: Codeunit "LSC POS GUI";
        XMLRequest: Text;
        XMLResponse: Text;
        RequestID: Text[50];
        PosMenuLineTemp: Record "LSC POS Menu Line" Temporary;
        Processed: Boolean;
        MsgResult: Text;
        FSNUtility: Codeunit "FSN Utility";
        CalPro: Codeunit "calculation process";

    procedure SetURL(NavigateToURL: Text)
    begin
        URL := NavigateToURL;
    end;

}