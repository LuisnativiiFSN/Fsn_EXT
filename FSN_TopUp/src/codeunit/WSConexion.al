codeunit 50032 "FSN WSConexion"
{
    TableNo = "LSC POS Menu Line";
    trigger OnRun()
    begin
        CASE Command OF
            '':
                EXIT;
            'WSECONEXIONPQ':
                PrintWSEPaquetigo("Current-RECEIPT", BODYGLOBAL, 'POS', Parameter, Rec);
            'WSRECARGA':
                Recarga("Current-RECEIPT", BODYGLOBAL, 'POS', Parameter, Rec, "Current-GUEST", Parameter, "Current-Message", "Set Current-Input");
        END;
    end;

    var
        BODYGLOBAL: Text;
        RESPONSEGLOBAL: Text;
        POSGUI: Codeunit "LSC POS GUI";
        CommandWS: Text;
        WSIdTransactionGlobal: Text;
        WSResponseGlobal: Text;
        WSMontoGlobal: Text;
        WSBalanceGlobal: Text;
        RecExitosaGlobal: Boolean;

    procedure SetBodyGlobal(pBODYGLOBAL: Text)
    begin
        BODYGLOBAL := pBODYGLOBAL;
    end;

    procedure GetResponseGlobals(): Text
    begin
        EXIT(RESPONSEGLOBAL);
    end;

    procedure WSIdTransactionGlobalR(): Text
    begin
        EXIT(WSIdTransactionGlobal);
    end;

    procedure WSResponseGlobalR(): Text
    begin
        EXIT(WSResponseGlobal);
    end;

    procedure WSMontoGlobalR(): Text
    begin
        EXIT(WSMontoGlobal);
    end;

    procedure WSBalanceGlobalR(): Text
    begin
        EXIT(WSBalanceGlobal);
    end;

    procedure RecExitosaGlobalR(): Boolean
    begin
        EXIT(RecExitosaGlobal);
    end;

    procedure PrintWSEPaquetigo(pReceipt: Code[20]; sbText: Text; pGroup: Code[20]; pCode: Code[20]; pRec: Record "LSC POS Menu Line")
    var
        uriObj: DotNet Uri;
        lgRequest: DotNet HttpWebRequest;
        stream: DotNet StreamWriter;
        lgResponse: DotNet HttpWebResponse;
        str: DotNet Stream;
        reader: DotNet XmlTextReader;
        document: DotNet XmlDocument;
        ascii: DotNet Encoding;
        xmlnodelist: DotNet XmlNodeList;
        xmlnode: DotNet XmlNode;
        xmlelement: DotNet XmlElement;
        xmlFinal: File;
        xmlStream: OutStream;
        url: Text;
        soapActionUrl: Text;
        _IP: Code[20];
        ParamV: Record "FSN Parameter";
        sb: DotNet StringBuilder;
    begin
        CLEAR(RESPONSEGLOBAL);
        sb := sb.StringBuilder(sbText);
        ParamV.RESET;
        ParamV.SETRANGE(ParamV.Grupo, pGroup);
        ParamV.SETRANGE(ParamV.Codigo, pCode);
        ParamV.SETRANGE(ParamV.Activo, TRUE);
        IF ParamV.FINDSET THEN BEGIN
            _IP := ParamV.IP;
            url := ParamV."Web Uri";
            soapActionUrl := ParamV."Web Action";

            IF pRec."Registration Mode" THEN
                IF ParamV."Save Xml" THEN BEGIN
                    IF xmlFinal.CREATE('C:\Temp\' + pCode + pReceipt + '-P .xml') THEN BEGIN
                        xmlFinal.CREATEOUTSTREAM(xmlStream);
                        xmlStream.WRITE(sb.ToString());
                        xmlFinal.CLOSE;
                    END;
                END;
            uriObj := uriObj.Uri(url);
            lgRequest := lgRequest.CreateDefault(uriObj);
            lgRequest.Method := 'POST';
            lgRequest.Host := _IP;
            lgRequest.ContentType := 'text/xml; charset=utf-8';
            lgRequest.Headers.Add('SOAPAction', soapActionUrl);
            lgRequest.Timeout := 90000;
            stream := stream.StreamWriter(lgRequest.GetRequestStream(), ascii.UTF8);
            stream.Write(sb.ToString());
            stream.Close();
            lgResponse := lgRequest.GetResponse();
            str := lgResponse.GetResponseStream();
            //reader := reader.XmlTextReader(str);
            IF pRec."Registration Mode" THEN BEGIN
                document := document.XmlDocument();
                /* CASE pCode OF
                    'PAQUETIGOP':
                        document.Load('C:\temp\PAQUETIGOCATALOGO.xml');
                    'PAQUETIGOR':
                        document.Load('C:\temp\PAQUETIGOR.xml');
                END; */
                document.Load(str);
                RESPONSEGLOBAL := document.OuterXml();
                IF ParamV."Save Xml" THEN BEGIN
                    document.Save('C:\temp\' + pCode + pReceipt + ' R .xml');
                END;
            END;
        END;
    end;

    procedure Recarga(pReceipt: Code[20]; sbText: Text; pGroup: Code[20]; pCode: Code[20]; pRec: Record "LSC POS Menu Line"; nodos: Integer; operador: Text; url: text[250]; soapActionUrl: Text)
    var
        uriObj: DotNet Uri;
        lgRequest: DotNet HttpWebRequest;
        stream: DotNet StreamWriter;
        lgResponse: DotNet HttpWebResponse;
        str: DotNet Stream;
        reader: DotNet XmlTextReader;
        document: DotNet XmlDocument;
        ascii: DotNet Encoding;
        xmlnodelist: DotNet XmlNodeList;
        xmlnode: DotNet XmlNode;
        xmlelement: DotNet XmlElement;
        xmlFinal: File;
        xmlStream: OutStream;
        _IP: Code[20];
        ParamV: Record "FSN Parameter";
        sb: DotNet StringBuilder;
        Index: Integer;
        st2: DotNet String;
    begin
        sb := sb.StringBuilder();

        sb.Append('<?xml version="1.0" encoding="utf-8"?><soap:Envelope ' +
        'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/"><soap:Body>');
        sb.Append(sbText);
        sb.Append('</soap:Body></soap:Envelope>');

        IF xmlFinal.CREATE('C:\temp\' + pReceipt + '-' + DELCHR(FORMAT(TODAY), '=', '/') + 'P.xml') THEN BEGIN
            xmlFinal.CREATEOUTSTREAM(xmlStream);
            xmlStream.WRITE(sb.ToString);
            xmlFinal.CLOSE;
        END;

        uriObj := uriObj.Uri(url);
        lgRequest := lgRequest.CreateDefault(uriObj);
        lgRequest.Method := 'POST';
        lgRequest.ContentType := 'text/xml; charset=utf-8';
        lgRequest.Headers.Add('SOAPAction', soapActionUrl);
        lgRequest.Timeout := 60000;
        stream := stream.StreamWriter(lgRequest.GetRequestStream(), ascii.UTF8);
        stream.Write(sb.ToString());
        stream.Close();
        lgResponse := lgRequest.GetResponse();
        str := lgResponse.GetResponseStream();
        document := document.XmlDocument();
        //reader := reader.XmlTextReader(str);
        document.Load(str);
        //document := document.XmlDocument();

        xmlnodelist := document.SelectNodes('//*');
        RESPONSEGLOBAL := document.OuterXml();
        document.Save('C:\temp\' + pReceipt + '-' + DELCHR(FORMAT(TODAY), '=', '/') + 'Rn' + FORMAT(nodos) + '.xml');
        RecExitosaGlobal := FALSE;

        CASE operador OF
            'Claro':
                BEGIN
                    Index := 0;
                    WHILE (Index < xmlnodelist.Count) DO BEGIN
                        xmlnode := xmlnodelist.Item(Index);
                        IF NOT ISNULL(xmlnode) THEN BEGIN
                            CASE xmlnode.Name OF
                                'TransaccionOperador':
                                    WSIdTransactionGlobal := xmlnode.FirstChild.InnerText;
                                'RespuestaServicio':
                                    WSResponseGlobal := xmlnode.FirstChild.InnerText;
                                'MontoAcreditado':
                                    WSMontoGlobal := xmlnode.FirstChild.InnerText;
                                'MontoDisponible':
                                    WSBalanceGlobal := xmlnode.FirstChild.InnerText;
                            END;
                        END;
                        Index += 1;
                    END;
                    IF WSResponseGlobal = '0' THEN
                        RecExitosaGlobal := TRUE;
                END;
            'Digicel':
                BEGIN
                    Index := 0;
                    WHILE (Index < xmlnodelist.Count) DO BEGIN
                        xmlnode := xmlnodelist.Item(Index);
                        IF NOT ISNULL(xmlnode) THEN BEGIN
                            CASE xmlnode.Name OF
                                'TransaccionOperador':
                                    WSIdTransactionGlobal := xmlnode.FirstChild.InnerText;
                                'RespuestaServicio':
                                    WSResponseGlobal := xmlnode.FirstChild.InnerText;
                                'MontoAcreditado':
                                    WSMontoGlobal := xmlnode.FirstChild.InnerText;
                                'MontoDisponible':
                                    WSBalanceGlobal := xmlnode.FirstChild.InnerText;
                            END;
                        END;
                        Index += 1;
                    END;
                    IF WSResponseGlobal = '0' THEN
                        RecExitosaGlobal := TRUE;


                END;
            'Telefonica':
                BEGIN
                    Index := 0;
                    WHILE (Index < xmlnodelist.Count) DO BEGIN
                        xmlnode := xmlnodelist.Item(Index);
                        IF NOT ISNULL(xmlnode) THEN BEGIN
                            CASE xmlnode.Name OF
                                'TransaccionOperador':
                                    WSIdTransactionGlobal := xmlnode.FirstChild.InnerText;
                                'RespuestaServicio':
                                    WSResponseGlobal := xmlnode.FirstChild.InnerText;
                                'MontoAcreditado':
                                    WSMontoGlobal := xmlnode.FirstChild.InnerText;
                                'MontoDisponible':
                                    WSBalanceGlobal := xmlnode.FirstChild.InnerText;
                            END;
                        END;
                        Index += 1;
                    END;
                    IF WSResponseGlobal = '00 OK' THEN
                        RecExitosaGlobal := TRUE;

                END;
            'Tigo':
                BEGIN
                    Index := 0;
                    WHILE (Index < xmlnodelist.Count) DO BEGIN
                        xmlnode := xmlnodelist.Item(Index);
                        IF NOT ISNULL(xmlnode) THEN BEGIN
                            CASE xmlnode.Name OF
                                'TransaccionOperador':
                                    WSIdTransactionGlobal := xmlnode.FirstChild.InnerText;
                                'RespuestaServicio':
                                    WSResponseGlobal := xmlnode.FirstChild.InnerText;
                                'MontoAcreditado':
                                    WSMontoGlobal := xmlnode.FirstChild.InnerText;
                                'MontoDisponible':
                                    WSBalanceGlobal := xmlnode.FirstChild.InnerText;
                            END;
                        END;
                        Index += 1;
                    END;
                    IF COPYSTR(WSResponseGlobal, 1, 13) = 'TopUp Exitoso' THEN
                        RecExitosaGlobal := TRUE;

                END;
        END;
    end;




}