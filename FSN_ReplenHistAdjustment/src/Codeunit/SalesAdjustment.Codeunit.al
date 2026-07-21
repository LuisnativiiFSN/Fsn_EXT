codeunit 50092 "FSN SalesAdjustment"
{

    trigger OnRun()
    begin
        GetInsertAndModifyHistReplen;
    end;

    procedure GetInsertAndModifyHistReplen()
    var
        SqlConnection: DotNet SqlConnection;
        SqlCommand: DotNet SqlCommand;
        SqlDataReader: DotNet SqlDataReader;
        ConnectionString: Text[125];
        SqlString: Text;
        RetailSetup: Record "LSC Retail Setup";
        DisLocation: Record "LSC Distribution Location";
        ForCount: Integer;
        lTextConn: Label 'Data Source=%1;Initial Catalog=%2;Integrated Security=false; User ID=%3;Password=%4;';
        lTextSimbol: Label '''''';
        _Location: Code[10];
        _ItemNo: Code[20];
        _VariantCode: Code[20];
        _SumRealQty: Decimal;
        _CurrentDate: Date;
        Ok_: Boolean;
        ReplenSalesAdj_l: Record "LSC Replen. Sales Hist. Adj.";
        Item_l: Record "Item";
    begin
        Ok_ := TRUE;
        RetailSetup.GET;
        IF NOT DisLocation.GET(RetailSetup."Distribution Location") THEN EXIT;

        ConnectionString := STRSUBSTNO(lTextConn, DisLocation."NAV Server Name", DisLocation."Db. Path && Name", DisLocation."User ID", DisLocation.Password);
        SqlConnection := SqlConnection.SqlConnection(ConnectionString);

        FOR ForCount := 0 TO 1 DO BEGIN
            IF ForCount > 0 THEN
                _CurrentDate := TODAY - ForCount
            ELSE
                _CurrentDate := TODAY;
            SqlString := 'SELECT L.[Location Code][LocationCode],L.[Item No_]ItemNo,L.[Variant Code]VariantCode,' +
                          'SUM(L.Quantity * U.[Qty_ per Unit of Measure])[RealQuantity] ' +
                          'FROM  [FASANI$Replen_ Sales Hist_ Adj_ Lines$a397324a-67fe-4557-aefb-aa375b30dbdf] L JOIN [FASANI$Item Unit of Measure$437dbf0e-84ff-417a-965d-ed2bb9650972] U ' +
                          'ON L.[Item No_]=U.[Item No_] AND L.[Unit of Measure]=U.Code ' +
                          'WHERE (L.Date BETWEEN CONVERT(DATE,GETDATE()-' + FORMAT(ForCount) + ') AND CONVERT(DATE,GETDATE()-' + FORMAT(ForCount) + '))' +
                          'GROUP BY L.[Location Code],L.[Item No_],L.[Variant Code];';
            SqlConnection.Open();
            SqlCommand := SqlConnection.CreateCommand();
            SqlCommand.CommandText := SqlString;
            SqlDataReader := SqlCommand.ExecuteReader();
            WHILE SqlDataReader.Read() DO BEGIN
                _Location := SqlDataReader.Item('LocationCode');
                _ItemNo := SqlDataReader.Item('ItemNo');
                _VariantCode := SqlDataReader.Item('VariantCode');
                _SumRealQty := SqlDataReader.Item('RealQuantity');
                IF NOT ReplenSalesAdj_l.GET(_ItemNo, _VariantCode, _Location, _CurrentDate) THEN BEGIN
                    ReplenSalesAdj_l.INIT;
                    ReplenSalesAdj_l."Item No." := _ItemNo;
                    ReplenSalesAdj_l."Variant Code" := _VariantCode;
                    ReplenSalesAdj_l."Location Code" := _Location;
                    ReplenSalesAdj_l.Date := _CurrentDate;
                    ReplenSalesAdj_l."Adjusted Qty" := _SumRealQty;
                    IF ReplenSalesAdj_l.INSERT(TRUE) THEN;
                END ELSE BEGIN
                    IF NOT (ReplenSalesAdj_l."Adjusted Qty" = _SumRealQty) THEN BEGIN
                        ReplenSalesAdj_l."Adjusted Qty" := _SumRealQty;
                        IF (ReplenSalesAdj_l."Division Code" = '') AND (ReplenSalesAdj_l."Item Category Code" = '') AND
                          (ReplenSalesAdj_l."Retail Product Code" = '') THEN BEGIN//"Product Group Code"
                            IF Item_l.GET(_ItemNo) THEN BEGIN
                                ReplenSalesAdj_l."Division Code" := Item_l."LSC Division Code";
                                ReplenSalesAdj_l."Item Category Code" := Item_l."Item Category Code";
                                ReplenSalesAdj_l."Retail Product Code" := Item_l."LSC Retail Product Code";
                            END;
                        END;
                        IF ReplenSalesAdj_l.MODIFY THEN;
                    END;
                END;
            END;
            SqlDataReader.Close();
            SqlConnection.Close();
        END;
    end;


    [EventSubscriber(ObjectType::Page, Page::"LSC Replen. Sales Hist. Adj.", 'OnAfterGetRecordEvent', '', true, true)]
    local procedure "Replen. Sales Hist. Adj._OnAfterGetRecordEvent"(var Rec: Record "LSC Replen. Sales Hist. Adj.")
    var
        "UnitPriceInclVAT": Decimal;
        Item: Record "Item";
    begin
        IF Item.GET(Rec."Item No.") THEN
            "UnitPriceInclVAT" := Item."LSC Unit Price Incl. VAT";
    end;

    procedure adjustQuantity(var LocationCode: Code[20]; Dt: Date; ItNo: Code[20])
    var
        NewQuantity: Integer;
        ItemUOM: Record "Item Unit of Measure";
        RSHA: Record "LSC Replen. Sales Hist. Adj.";
        ReplenishmentSalesHistoryLines: Record "FSN Replen. Sales Adj. Line";
    begin

        RSHA.RESET;
        RSHA.SETRANGE("Location Code", LocationCode);
        RSHA.SETRANGE(Date, Dt);
        RSHA.SETRANGE("Item No.", ItNo);
        IF RSHA.FIND('-') THEN
            REPEAT
                NewQuantity := 0;
                ReplenishmentSalesHistoryLines.RESET;
                ReplenishmentSalesHistoryLines.SETRANGE("Location Code", LocationCode);
                ReplenishmentSalesHistoryLines.SETRANGE(Date, Dt);
                ReplenishmentSalesHistoryLines.SETRANGE("Item No.", RSHA."Item No.");
                IF ReplenishmentSalesHistoryLines.FIND('-') THEN
                    REPEAT
                        ItemUOM.RESET;
                        ItemUOM.SETRANGE("Item No.", ReplenishmentSalesHistoryLines."Item No.");
                        ItemUOM.SETRANGE(Code, ReplenishmentSalesHistoryLines."Unit of Measure");
                        IF ItemUOM.FINDFIRST THEN
                            NewQuantity := NewQuantity + (ReplenishmentSalesHistoryLines.Quantity * ItemUOM."Qty. per Unit of Measure")
                        ELSE
                            NewQuantity := NewQuantity + ReplenishmentSalesHistoryLines.Quantity;
                    UNTIL ReplenishmentSalesHistoryLines.NEXT = 0;
                RSHA."Adjusted Qty" := NewQuantity;
                IF NewQuantity = 0 THEN
                    RSHA.DELETE
                ELSE
                    RSHA.MODIFY;
            UNTIL RSHA.NEXT = 0;

    end;
}

