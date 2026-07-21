/// <summary>
/// Codeunit FSN POS Command Extend (ID 50096).
/// </summary>
codeunit 50096 "FSN POS Command Extend"
{

    TableNo = "LSC POS Menu Line";

    var
        Text002: Label 'Password must be manager';

    procedure MembershipCardConfirm(pPOSTransaction: Record "LSC POS Transaction"; var ErrorText: Text): Boolean
    var
        lMemberShip: Record "LSC Membership Card";
        lScheme: Record "LSC Member Scheme";
        lAccount: Record "LSC Member Account";
        lText001: Label 'Card %1 not exits';
        lText002: Label '%1 is not valid';
        lSchemeCode: Code[10];
        POSView: Codeunit "LSC POS View";
        lText003: Label 'Card be scanned, try again';
        lText004: Label 'Not match. Expected card %1, scann %2';
        lMostrarPagos: Record "LSC Delivery Order";
    begin
        IF pPOSTransaction."Member Card No." = '' THEN BEGIN
            ErrorText := STRSUBSTNO(lText001, pPOSTransaction."Member Card No.");
            EXIT(FALSE);
        END;
        IF NOT lMemberShip.GET(pPOSTransaction."Member Card No.") THEN BEGIN
            ErrorText := STRSUBSTNO(lText001, pPOSTransaction."Member Card No.");
            EXIT(FALSE);
        END;
        lSchemeCode := lMemberShip."Scheme Code";
        IF lSchemeCode = '' THEN
            IF NOT lAccount.GET(lMemberShip."Account No.") THEN BEGIN
                ErrorText := STRSUBSTNO(lText002, lAccount.TABLECAPTION);
                EXIT(FALSE);
            END ELSE
                lSchemeCode := lAccount."Scheme Code";
        IF (lSchemeCode = '') OR NOT (lScheme.GET(lSchemeCode)) THEN BEGIN
            ErrorText := STRSUBSTNO(lText002, lScheme.TABLECAPTION);
            EXIT(FALSE);
        END;
        lMostrarPagos.RESET;
        lMostrarPagos.SETRANGE(lMostrarPagos."Invoice No.", pPOSTransaction."Receipt No.");
        IF lMostrarPagos.FINDFIRST THEN BEGIN
            IF POSView.Login(TRUE, '') THEN
                EXIT(TRUE)
            ELSE BEGIN
                ErrorText := Text002;
                EXIT(FALSE);
            END;
        END;
        IF (lScheme.Code = 'VIP_BA') OR pPOSTransaction."Sale Is Return Sale" THEN BEGIN//Logical static
            IF POSView.Login(TRUE, '') THEN
                EXIT(TRUE)
            ELSE BEGIN
                ErrorText := Text002;
                EXIT(FALSE);
            END;
        END ELSE BEGIN
            /*olopez wsControl2 := wsControl2.Masters();
             wsControl2.setDifPermission(2);
             wsControl2.setLenEnd(9);
             wsControl2.ShowDialog();
             IF NOT wsControl2.Scanned() THEN BEGIN
                 ErrorText := lText003;
                 EXIT(FALSE);
             END;
             IF wsControl2.cardScann <> pPOSTransaction."Member Card No." THEN BEGIN
                 ErrorText := STRSUBSTNO(lText004, pPOSTransaction."Member Card No.", wsControl2.cardScann);
                 EXIT(FALSE);
             END ELSE BEGIN
                 EXIT(TRUE);
             END; olopez*/
        END;
    end;

    procedure PointsCalcMemberExtend(var pTransLine: Record "LSC Trans. Sales Entry"; var pCurrPoints: Decimal; MemberPointSetupTemp_l: Record "LSC Member Point Setup" temporary)
    begin
        IF (pCurrPoints = 0) OR (pTransLine."Receipt No." = '') OR
          NOT (MemberPointSetupTemp_l."Points Type" = MemberPointSetupTemp_l."Points Type"::"Award Points") THEN
            EXIT;

        IF COPYSTR(pTransLine."Receipt No.", 1, 10) = '00000APP01' THEN BEGIN
            pCurrPoints := pCurrPoints * 2;
        END;
    end;
}