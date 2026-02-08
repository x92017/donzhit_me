// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appTitle => 'DonzHit.me';

  @override
  String get navHome => 'Inicio';

  @override
  String get navReport => 'Reportar';

  @override
  String get navPosts => 'Publicaciones';

  @override
  String get navSettings => 'Ajustes';

  @override
  String get navAdmin => 'Admin';

  @override
  String get homeSubtitle => 'Reportar violaciones de tráfico/peatones';

  @override
  String get allLocations => 'Todas las ubicaciones';

  @override
  String get stateProvince => 'Estado/Provincia';

  @override
  String get cityOptional => 'Ciudad (Opcional)';

  @override
  String filterByCity(String state) {
    return 'Filtrar por ciudad en $state';
  }

  @override
  String get eventTypeAll => 'Todos';

  @override
  String get eventTypePedestrianIntersection => 'Intersección peatonal';

  @override
  String get eventTypeRedLight => 'Luz roja';

  @override
  String get eventTypeSpeeding => 'Exceso de velocidad';

  @override
  String get eventTypeOnPhone => 'Usando teléfono';

  @override
  String get eventTypeReckless => 'Conducción temeraria';

  @override
  String get uploaded => 'Subido';

  @override
  String get incident => 'Incidente';

  @override
  String get signIn => 'Iniciar sesión';

  @override
  String get signInWithGoogle => 'Iniciar sesión con Google';

  @override
  String get signOut => 'Cerrar sesión';

  @override
  String get signInFailed => 'Error al iniciar sesión. Inténtalo de nuevo.';

  @override
  String get signInRequired => 'Inicio de sesión requerido';

  @override
  String get signInToReport =>
      'Ayuda a hacer nuestras carreteras más seguras reportando comportamientos peligrosos';

  @override
  String get signInTo => 'Inicia sesión para:';

  @override
  String get benefitUploadMedia => 'Subir videos y fotos de incidentes';

  @override
  String get benefitReportDetails =>
      'Reportar ubicación y detalles del incidente';

  @override
  String get benefitTrackReports => 'Seguir tus reportes enviados';

  @override
  String get benefitReactComment => 'Reaccionar y comentar en reportes';

  @override
  String get privacyNote =>
      'Tu privacidad es importante. Solo usamos tu email para autenticación.';

  @override
  String get reportTitle => 'Reportar una Violación de Tráfico';

  @override
  String get reportSubtitle =>
      'Completa el formulario con los detalles del incidente';

  @override
  String get reportATrafficIncident => 'Reportar un Incidente de Tráfico';

  @override
  String get formTitle => 'Título';

  @override
  String get formTitleHint => 'Ingresa un título breve para el incidente';

  @override
  String get formTitleRequired => 'Por favor ingresa un título';

  @override
  String get formDescription => 'Descripción';

  @override
  String get formDescriptionHint => 'Describe lo que sucedió en detalle';

  @override
  String get formDescriptionRequired => 'Por favor ingresa una descripción';

  @override
  String get formDateTime => 'Fecha/Hora';

  @override
  String get formRoadUsage =>
      'Uso de la vía (selecciona todos los que apliquen)';

  @override
  String get formRoadUsageRequired =>
      'Por favor selecciona al menos un tipo de uso de vía';

  @override
  String get formEventType =>
      'Tipo de evento (selecciona todos los que apliquen)';

  @override
  String get formEventTypeRequired =>
      'Por favor selecciona al menos un tipo de evento';

  @override
  String get formInjuries => '¿Alguna lesión?';

  @override
  String get formInjuriesHint =>
      'Describe las lesiones ocurridas (o \"Ninguna\")';

  @override
  String get formInjuriesRequired =>
      'Por favor describe las lesiones (o ingresa \"Ninguna\")';

  @override
  String get formStateRequired => 'Por favor selecciona un estado o provincia';

  @override
  String get submitReport => 'Enviar Reporte';

  @override
  String get submitting => 'Enviando...';

  @override
  String get reportSubmitted => '¡Reporte enviado exitosamente!';

  @override
  String get reportSubmitFailed => 'Error al enviar el reporte';

  @override
  String get yourPastPosts => 'Tus Publicaciones Anteriores';

  @override
  String get searchReports => 'Buscar reportes...';

  @override
  String get noReportsFound => 'No se encontraron reportes';

  @override
  String get noReportsYet => 'Aún no has enviado ningún reporte';

  @override
  String get settings => 'Ajustes';

  @override
  String get language => 'Idioma';

  @override
  String get english => 'Inglés';

  @override
  String get spanish => 'Español';

  @override
  String get defaultStateProvince => 'Estado/Provincia predeterminado';

  @override
  String get theme => 'Tema';

  @override
  String get themeSystem => 'Sistema';

  @override
  String get themeLight => 'Claro';

  @override
  String get themeDark => 'Oscuro';

  @override
  String get admin => 'Administración';

  @override
  String get pendingReports => 'Reportes pendientes';

  @override
  String get approve => 'Aprobar';

  @override
  String get reject => 'Rechazar';

  @override
  String get clearFilters => 'Limpiar filtros';

  @override
  String get noApprovedReports => 'Aún no hay reportes aprobados';

  @override
  String get noMatchingReports =>
      'No hay reportes aprobados que coincidan con tus filtros';

  @override
  String get comments => 'Comentarios';

  @override
  String get addComment => 'Agregar un comentario...';

  @override
  String get pleaseSignInToComment => 'Por favor inicia sesión para comentar';

  @override
  String get pleaseSignInToReact => 'Por favor inicia sesión para reaccionar';

  @override
  String get cancel => 'Cancelar';

  @override
  String get save => 'Guardar';

  @override
  String get delete => 'Eliminar';

  @override
  String get edit => 'Editar';

  @override
  String get close => 'Cerrar';

  @override
  String get ok => 'OK';

  @override
  String get error => 'Error';

  @override
  String get loading => 'Cargando...';

  @override
  String get retry => 'Reintentar';
}
