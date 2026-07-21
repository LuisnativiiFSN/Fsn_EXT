controladdin ScanVip
{
    HorizontalStretch = true;
    VerticalStretch = true;
    RequestedWidth = 500;
    RequestedHeight = 400;


    Scripts = 'src/assets/js/jquery-3.4.1.min.js',
        'src/assets/js/popper.min.js',
        'src/assets/js/bootstrap.min.js',
        'src/assets/js/start.js';

    StyleSheets = 'src/assets/css/bootstrap.min.css',
    'src/assets/css/businesscentral-colors.css',
    'src/assets/css/businesscentral-font.css',
    'src/assets/css/style.css';

    StartupScript = 'src/assets/js/startup.js';
    //Images = 'src/assets/scanvip.html';

    event Onload()
    event OnCancel()
    event OnTimeOut(inputText: Text)
    event RecivedDataToAL(inputText: Text)
    Procedure GetVIP()

}


