import 'package:flutter/material.dart';
import '../models/category.dart';

const List<ServiceCategory> allCategories = [
  // 💅 Uñas
  ServiceCategory(
    id: 'nails',
    nameEs: 'Uñas',
    icon: '💅',
    color: Color(0xFFE91E63),
    subcategories: [
      ServiceSubcategory(
        id: 'manicure',
        categoryId: 'nails',
        nameEs: 'Manicure',
        items: [
          ServiceItem(
            id: 'manicure_clasico',
            subcategoryId: 'manicure',
            nameEs: 'Clásico',
            serviceType: 'manicure_clasico',
          ),
          ServiceItem(
            id: 'manicure_gel',
            subcategoryId: 'manicure',
            nameEs: 'Gel',
            serviceType: 'manicure_gel',
          ),
          ServiceItem(
            id: 'manicure_frances',
            subcategoryId: 'manicure',
            nameEs: 'Francés',
            serviceType: 'manicure_frances',
          ),
          ServiceItem(
            id: 'manicure_dip_powder',
            subcategoryId: 'manicure',
            nameEs: 'Dip Powder',
            serviceType: 'manicure_dip_powder',
          ),
          ServiceItem(
            id: 'manicure_acrilico',
            subcategoryId: 'manicure',
            nameEs: 'Acrílico',
            serviceType: 'manicure_acrilico',
          ),
          ServiceItem(
            id: 'manicure_spa',
            subcategoryId: 'manicure',
            nameEs: 'Spa/Luxury',
            serviceType: 'manicure_spa_luxury',
          ),
          ServiceItem(
            id: 'manicure_japones',
            subcategoryId: 'manicure',
            nameEs: 'Japonés',
            serviceType: 'manicure_japones',
          ),
          ServiceItem(
            id: 'manicure_parafina',
            subcategoryId: 'manicure',
            nameEs: 'Parafina',
            serviceType: 'manicure_parafina',
          ),
          ServiceItem(
            id: 'manicure_ruso',
            subcategoryId: 'manicure',
            nameEs: 'Ruso',
            serviceType: 'manicure_ruso',
          ),
        ],
      ),
      ServiceSubcategory(
        id: 'pedicure',
        categoryId: 'nails',
        nameEs: 'Pedicure',
        items: [
          ServiceItem(
            id: 'pedicure_clasico',
            subcategoryId: 'pedicure',
            nameEs: 'Clásico',
            serviceType: 'pedicure_clasico',
          ),
          ServiceItem(
            id: 'pedicure_spa',
            subcategoryId: 'pedicure',
            nameEs: 'Spa/Luxury',
            serviceType: 'pedicure_spa_luxury',
          ),
          ServiceItem(
            id: 'pedicure_gel',
            subcategoryId: 'pedicure',
            nameEs: 'Gel',
            serviceType: 'pedicure_gel',
          ),
          ServiceItem(
            id: 'pedicure_medico',
            subcategoryId: 'pedicure',
            nameEs: 'Médico',
            serviceType: 'pedicure_medico',
          ),
          ServiceItem(
            id: 'pedicure_parafina',
            subcategoryId: 'pedicure',
            nameEs: 'Parafina',
            serviceType: 'pedicure_parafina',
          ),
        ],
      ),
      ServiceSubcategory(
        id: 'nail_art',
        categoryId: 'nails',
        nameEs: 'Nail Art',
        items: [
          ServiceItem(id: 'nail_art_diseno', subcategoryId: 'nail_art', nameEs: 'Diseño Personalizado', serviceType: 'nail_art_diseno'),
          ServiceItem(id: 'nail_art_3d', subcategoryId: 'nail_art', nameEs: '3D / Relieve', serviceType: 'nail_art_3d'),
          ServiceItem(id: 'nail_art_stamping', subcategoryId: 'nail_art', nameEs: 'Stamping', serviceType: 'nail_art_stamping'),
        ],
      ),
      ServiceSubcategory(
        id: 'cambio_esmalte',
        categoryId: 'nails',
        nameEs: 'Cambio de Esmalte',
        items: [
          ServiceItem(id: 'cambio_esmalte_manos', subcategoryId: 'cambio_esmalte', nameEs: 'Manos', serviceType: 'cambio_esmalte_manos'),
          ServiceItem(id: 'cambio_esmalte_pies', subcategoryId: 'cambio_esmalte', nameEs: 'Pies', serviceType: 'cambio_esmalte_pies'),
        ],
      ),
      ServiceSubcategory(
        id: 'reparacion',
        categoryId: 'nails',
        nameEs: 'Reparación',
        items: [
          ServiceItem(id: 'reparacion_una', subcategoryId: 'reparacion', nameEs: 'Reparación de Uña', serviceType: 'reparacion_una'),
        ],
      ),
      ServiceSubcategory(
        id: 'relleno',
        categoryId: 'nails',
        nameEs: 'Relleno',
        items: [
          ServiceItem(id: 'relleno_acrilico', subcategoryId: 'relleno', nameEs: 'Acrílico', serviceType: 'relleno_acrilico'),
          ServiceItem(id: 'relleno_gel', subcategoryId: 'relleno', nameEs: 'Gel', serviceType: 'relleno_gel'),
        ],
      ),
      ServiceSubcategory(
        id: 'retiro',
        categoryId: 'nails',
        nameEs: 'Retiro',
        items: [
          ServiceItem(id: 'retiro_acrilico', subcategoryId: 'retiro', nameEs: 'Acrílico', serviceType: 'retiro_acrilico'),
          ServiceItem(id: 'retiro_gel', subcategoryId: 'retiro', nameEs: 'Gel', serviceType: 'retiro_gel'),
        ],
      ),
    ],
  ),

  // ✂️ Cabello
  ServiceCategory(
    id: 'hair',
    nameEs: 'Cabello',
    icon: '✂️',
    color: Color(0xFF8D6E63),
    subcategories: [
      ServiceSubcategory(
        id: 'corte',
        categoryId: 'hair',
        nameEs: 'Corte',
        items: [
          ServiceItem(
            id: 'corte_mujer',
            subcategoryId: 'corte',
            nameEs: 'Mujer',
            serviceType: 'corte_mujer',
          ),
          ServiceItem(
            id: 'corte_hombre',
            subcategoryId: 'corte',
            nameEs: 'Hombre',
            serviceType: 'corte_hombre',
          ),
          ServiceItem(
            id: 'corte_nino',
            subcategoryId: 'corte',
            nameEs: 'Niño/a',
            serviceType: 'corte_nino',
          ),
        ],
      ),
      ServiceSubcategory(
        id: 'color',
        categoryId: 'hair',
        nameEs: 'Color',
        items: [
          ServiceItem(
            id: 'color_tinte_completo',
            subcategoryId: 'color',
            nameEs: 'Tinte Completo',
            serviceType: 'tinte_completo',
          ),
          ServiceItem(
            id: 'color_retoque_raiz',
            subcategoryId: 'color',
            nameEs: 'Retoque de Raíz',
            serviceType: 'retoque_raiz',
          ),
          ServiceItem(
            id: 'color_mechas',
            subcategoryId: 'color',
            nameEs: 'Mechas',
            serviceType: 'mechas_highlights',
          ),
          ServiceItem(
            id: 'color_balayage',
            subcategoryId: 'color',
            nameEs: 'Balayage',
            serviceType: 'balayage',
          ),
          ServiceItem(
            id: 'color_ombre',
            subcategoryId: 'color',
            nameEs: 'Ombré',
            serviceType: 'ombre',
          ),
          ServiceItem(
            id: 'color_correccion',
            subcategoryId: 'color',
            nameEs: 'Corrección',
            serviceType: 'correccion_color',
          ),
          ServiceItem(
            id: 'color_decoloracion',
            subcategoryId: 'color',
            nameEs: 'Decoloración',
            serviceType: 'decoloracion',
          ),
        ],
      ),
      ServiceSubcategory(
        id: 'tratamiento',
        categoryId: 'hair',
        nameEs: 'Tratamiento',
        items: [
          ServiceItem(
            id: 'tratamiento_keratina',
            subcategoryId: 'tratamiento',
            nameEs: 'Keratina',
            serviceType: 'keratina_alisado',
          ),
          ServiceItem(
            id: 'tratamiento_botox',
            subcategoryId: 'tratamiento',
            nameEs: 'Botox Capilar',
            serviceType: 'botox_capilar',
          ),
          ServiceItem(
            id: 'tratamiento_hidratacion',
            subcategoryId: 'tratamiento',
            nameEs: 'Hidratación',
            serviceType: 'hidratacion_profunda',
          ),
          ServiceItem(
            id: 'tratamiento_olaplex',
            subcategoryId: 'tratamiento',
            nameEs: 'Olaplex',
            serviceType: 'olaplex_reconstructor',
          ),
          ServiceItem(
            id: 'tratamiento_anticaida',
            subcategoryId: 'tratamiento',
            nameEs: 'Anticaída',
            serviceType: 'tratamiento_anticaida',
          ),
        ],
      ),
      ServiceSubcategory(
        id: 'peinado',
        categoryId: 'hair',
        nameEs: 'Peinado',
        items: [
          ServiceItem(
            id: 'peinado_blowout',
            subcategoryId: 'peinado',
            nameEs: 'Blowout',
            serviceType: 'blowout_secado',
          ),
          ServiceItem(
            id: 'peinado_planchado',
            subcategoryId: 'peinado',
            nameEs: 'Planchado',
            serviceType: 'planchado',
          ),
          ServiceItem(
            id: 'peinado_ondas',
            subcategoryId: 'peinado',
            nameEs: 'Ondas',
            serviceType: 'ondas_rizos',
          ),
          ServiceItem(
            id: 'peinado_recogido',
            subcategoryId: 'peinado',
            nameEs: 'Recogido',
            serviceType: 'recogido_evento',
          ),
          ServiceItem(
            id: 'peinado_trenzas',
            subcategoryId: 'peinado',
            nameEs: 'Trenzas',
            serviceType: 'trenzas',
          ),
        ],
      ),
      ServiceSubcategory(
        id: 'extensiones',
        categoryId: 'hair',
        nameEs: 'Extensiones',
        items: [
          ServiceItem(
            id: 'extensiones_clip',
            subcategoryId: 'extensiones',
            nameEs: 'Clip-In',
            serviceType: 'ext_clip_in',
          ),
          ServiceItem(
            id: 'extensiones_cosidas',
            subcategoryId: 'extensiones',
            nameEs: 'Cosidas',
            serviceType: 'ext_cosidas',
          ),
          ServiceItem(
            id: 'extensiones_fusion',
            subcategoryId: 'extensiones',
            nameEs: 'Fusión',
            serviceType: 'ext_fusion_keratina',
          ),
          ServiceItem(
            id: 'extensiones_cinta',
            subcategoryId: 'extensiones',
            nameEs: 'Cinta',
            serviceType: 'ext_cinta_tape_in',
          ),
        ],
      ),
    ],
  ),

  // 👁️ Pestañas y Cejas
  ServiceCategory(
    id: 'lashes_brows',
    nameEs: 'Pestañas y Cejas',
    icon: '👁️',
    color: Color(0xFF9C27B0),
    subcategories: [
      ServiceSubcategory(
        id: 'pestanas',
        categoryId: 'lashes_brows',
        nameEs: 'Pestañas',
        items: [
          ServiceItem(
            id: 'pestanas_clasicas',
            subcategoryId: 'pestanas',
            nameEs: 'Clásicas',
            serviceType: 'ext_pestanas_clasicas',
          ),
          ServiceItem(
            id: 'pestanas_hibridas',
            subcategoryId: 'pestanas',
            nameEs: 'Híbridas',
            serviceType: 'ext_pestanas_hibridas',
          ),
          ServiceItem(
            id: 'pestanas_volumen',
            subcategoryId: 'pestanas',
            nameEs: 'Volumen',
            serviceType: 'ext_pestanas_volumen',
          ),
          ServiceItem(
            id: 'pestanas_mega_volumen',
            subcategoryId: 'pestanas',
            nameEs: 'Mega Volumen',
            serviceType: 'ext_pestanas_mega_volumen',
          ),
          ServiceItem(
            id: 'pestanas_lifting',
            subcategoryId: 'pestanas',
            nameEs: 'Lifting',
            serviceType: 'lifting_pestanas',
          ),
          ServiceItem(
            id: 'pestanas_tinte',
            subcategoryId: 'pestanas',
            nameEs: 'Tinte',
            serviceType: 'tinte_pestanas',
          ),
          ServiceItem(
            id: 'pestanas_relleno',
            subcategoryId: 'pestanas',
            nameEs: 'Relleno',
            serviceType: 'relleno_pestanas',
          ),
          ServiceItem(
            id: 'pestanas_retiro',
            subcategoryId: 'pestanas',
            nameEs: 'Retiro',
            serviceType: 'retiro_pestanas',
          ),
        ],
      ),
      ServiceSubcategory(
        id: 'cejas',
        categoryId: 'lashes_brows',
        nameEs: 'Cejas',
        items: [
          ServiceItem(
            id: 'cejas_diseno',
            subcategoryId: 'cejas',
            nameEs: 'Diseño',
            serviceType: 'diseno_depilacion_cejas',
          ),
          ServiceItem(
            id: 'cejas_microblading',
            subcategoryId: 'cejas',
            nameEs: 'Microblading',
            serviceType: 'microblading',
          ),
          ServiceItem(
            id: 'cejas_micropigmentacion',
            subcategoryId: 'cejas',
            nameEs: 'Micropigmentación',
            serviceType: 'micropigmentacion_cejas',
          ),
          ServiceItem(
            id: 'cejas_laminado',
            subcategoryId: 'cejas',
            nameEs: 'Laminado',
            serviceType: 'laminado_cejas',
          ),
          ServiceItem(
            id: 'cejas_tinte',
            subcategoryId: 'cejas',
            nameEs: 'Tinte',
            serviceType: 'tinte_cejas',
          ),
          ServiceItem(
            id: 'cejas_henna',
            subcategoryId: 'cejas',
            nameEs: 'Henna',
            serviceType: 'henna_cejas',
          ),
        ],
      ),
      ServiceSubcategory(
        id: 'combo',
        categoryId: 'lashes_brows',
        nameEs: 'Combo',
        items: [
          ServiceItem(id: 'combo_pestanas_cejas', subcategoryId: 'combo', nameEs: 'Pestañas + Cejas', serviceType: 'combo_pestanas_cejas'),
          ServiceItem(id: 'combo_lifting_tinte', subcategoryId: 'combo', nameEs: 'Lifting + Tinte', serviceType: 'combo_lifting_tinte'),
        ],
      ),
    ],
  ),

  // 💄 Maquillaje
  ServiceCategory(
    id: 'makeup',
    nameEs: 'Maquillaje',
    icon: '💄',
    color: Color(0xFFFF5252),
    subcategories: [
      ServiceSubcategory(
        id: 'maquillaje_social',
        categoryId: 'makeup',
        nameEs: 'Social',
        items: [
          ServiceItem(id: 'maquillaje_social_item', subcategoryId: 'maquillaje_social', nameEs: 'Maquillaje Social', serviceType: 'maquillaje_social'),
        ],
      ),
      ServiceSubcategory(
        id: 'maquillaje_evento',
        categoryId: 'makeup',
        nameEs: 'Evento',
        items: [
          ServiceItem(id: 'maquillaje_evento_item', subcategoryId: 'maquillaje_evento', nameEs: 'Maquillaje de Evento', serviceType: 'maquillaje_evento'),
        ],
      ),
      ServiceSubcategory(
        id: 'maquillaje_novia',
        categoryId: 'makeup',
        nameEs: 'Novia',
        items: [
          ServiceItem(id: 'maquillaje_novia_item', subcategoryId: 'maquillaje_novia', nameEs: 'Maquillaje de Novia', serviceType: 'maquillaje_novia'),
          ServiceItem(id: 'maquillaje_novia_prueba', subcategoryId: 'maquillaje_novia', nameEs: 'Prueba de Novia', serviceType: 'maquillaje_novia_prueba'),
        ],
      ),
      ServiceSubcategory(
        id: 'maquillaje_xv',
        categoryId: 'makeup',
        nameEs: 'XV Años',
        items: [
          ServiceItem(id: 'maquillaje_xv_item', subcategoryId: 'maquillaje_xv', nameEs: 'Maquillaje XV Años', serviceType: 'maquillaje_xv'),
        ],
      ),
      ServiceSubcategory(
        id: 'maquillaje_editorial',
        categoryId: 'makeup',
        nameEs: 'Editorial',
        items: [
          ServiceItem(id: 'maquillaje_editorial_item', subcategoryId: 'maquillaje_editorial', nameEs: 'Maquillaje Editorial', serviceType: 'maquillaje_editorial'),
        ],
      ),
      ServiceSubcategory(
        id: 'maquillaje_clase',
        categoryId: 'makeup',
        nameEs: 'Clase',
        items: [
          ServiceItem(id: 'maquillaje_clase_item', subcategoryId: 'maquillaje_clase', nameEs: 'Clase de Maquillaje', serviceType: 'maquillaje_clase'),
        ],
      ),
      ServiceSubcategory(
        id: 'maquillaje_prueba',
        categoryId: 'makeup',
        nameEs: 'Prueba',
        items: [
          ServiceItem(id: 'maquillaje_prueba_item', subcategoryId: 'maquillaje_prueba', nameEs: 'Prueba de Maquillaje', serviceType: 'maquillaje_prueba'),
        ],
      ),
    ],
  ),

  // 💆 Facial
  ServiceCategory(
    id: 'facial',
    nameEs: 'Facial',
    icon: '💆',
    color: Color(0xFF26A69A),
    subcategories: [
      ServiceSubcategory(
        id: 'limpieza',
        categoryId: 'facial',
        nameEs: 'Limpieza',
        items: [
          ServiceItem(
            id: 'limpieza_basica',
            subcategoryId: 'limpieza',
            nameEs: 'Básica',
            serviceType: 'limpieza_facial_basica',
          ),
          ServiceItem(
            id: 'limpieza_profunda',
            subcategoryId: 'limpieza',
            nameEs: 'Profunda',
            serviceType: 'limpieza_facial_profunda',
          ),
          ServiceItem(
            id: 'limpieza_hidrafacial',
            subcategoryId: 'limpieza',
            nameEs: 'Hidrafacial',
            serviceType: 'hidrafacial',
          ),
        ],
      ),
      ServiceSubcategory(
        id: 'facial_antiedad',
        categoryId: 'facial',
        nameEs: 'Anti-Edad',
        items: [
          ServiceItem(id: 'facial_antiedad_item', subcategoryId: 'facial_antiedad', nameEs: 'Tratamiento Anti-Edad', serviceType: 'facial_antiedad'),
        ],
      ),
      ServiceSubcategory(
        id: 'facial_antiacne',
        categoryId: 'facial',
        nameEs: 'Anti-Acné',
        items: [
          ServiceItem(id: 'facial_antiacne_item', subcategoryId: 'facial_antiacne', nameEs: 'Tratamiento Anti-Acné', serviceType: 'facial_antiacne'),
        ],
      ),
      ServiceSubcategory(
        id: 'facial_microdermoabrasion',
        categoryId: 'facial',
        nameEs: 'Microdermoabrasión',
        items: [
          ServiceItem(id: 'facial_microdermoabrasion_item', subcategoryId: 'facial_microdermoabrasion', nameEs: 'Microdermoabrasión', serviceType: 'facial_microdermoabrasion'),
        ],
      ),
      ServiceSubcategory(
        id: 'facial_dermapen',
        categoryId: 'facial',
        nameEs: 'Dermapen',
        items: [
          ServiceItem(id: 'facial_dermapen_item', subcategoryId: 'facial_dermapen', nameEs: 'Dermapen / Microneedling', serviceType: 'facial_dermapen'),
        ],
      ),
      ServiceSubcategory(
        id: 'facial_peeling',
        categoryId: 'facial',
        nameEs: 'Peeling',
        items: [
          ServiceItem(id: 'facial_peeling_quimico', subcategoryId: 'facial_peeling', nameEs: 'Químico', serviceType: 'peeling_quimico'),
          ServiceItem(id: 'facial_peeling_enzimatico', subcategoryId: 'facial_peeling', nameEs: 'Enzimático', serviceType: 'peeling_enzimatico'),
        ],
      ),
      ServiceSubcategory(
        id: 'facial_radiofrecuencia',
        categoryId: 'facial',
        nameEs: 'Radiofrecuencia',
        items: [
          ServiceItem(id: 'facial_radiofrecuencia_item', subcategoryId: 'facial_radiofrecuencia', nameEs: 'Radiofrecuencia Facial', serviceType: 'radiofrecuencia_facial'),
        ],
      ),
      ServiceSubcategory(
        id: 'facial_led',
        categoryId: 'facial',
        nameEs: 'LED',
        items: [
          ServiceItem(id: 'facial_led_item', subcategoryId: 'facial_led', nameEs: 'Terapia LED', serviceType: 'terapia_led_facial'),
        ],
      ),
      ServiceSubcategory(
        id: 'facial_mascarilla',
        categoryId: 'facial',
        nameEs: 'Mascarilla',
        items: [
          ServiceItem(id: 'facial_mascarilla_item', subcategoryId: 'facial_mascarilla', nameEs: 'Mascarilla Facial', serviceType: 'mascarilla_facial'),
        ],
      ),
    ],
  ),

  // 🧖 Cuerpo y Spa
  ServiceCategory(
    id: 'body_spa',
    nameEs: 'Cuerpo y Spa',
    icon: '🧖',
    color: Color(0xFF5C6BC0),
    subcategories: [
      ServiceSubcategory(
        id: 'masaje',
        categoryId: 'body_spa',
        nameEs: 'Masaje',
        items: [
          ServiceItem(
            id: 'masaje_relajante',
            subcategoryId: 'masaje',
            nameEs: 'Relajante',
            serviceType: 'masaje_relajante',
          ),
          ServiceItem(
            id: 'masaje_descontracturante',
            subcategoryId: 'masaje',
            nameEs: 'Descontracturante',
            serviceType: 'masaje_descontracturante',
          ),
          ServiceItem(
            id: 'masaje_piedras',
            subcategoryId: 'masaje',
            nameEs: 'Piedras Calientes',
            serviceType: 'masaje_piedras_calientes',
          ),
          ServiceItem(
            id: 'masaje_prenatal',
            subcategoryId: 'masaje',
            nameEs: 'Prenatal',
            serviceType: 'masaje_prenatal',
          ),
          ServiceItem(
            id: 'masaje_reflexologia',
            subcategoryId: 'masaje',
            nameEs: 'Reflexología',
            serviceType: 'reflexologia',
          ),
          ServiceItem(
            id: 'masaje_drenaje',
            subcategoryId: 'masaje',
            nameEs: 'Drenaje',
            serviceType: 'drenaje_linfatico',
          ),
        ],
      ),
      ServiceSubcategory(
        id: 'depilacion',
        categoryId: 'body_spa',
        nameEs: 'Depilación',
        items: [
          ServiceItem(
            id: 'depilacion_cera',
            subcategoryId: 'depilacion',
            nameEs: 'Cera',
            serviceType: 'depilacion_cera',
          ),
          ServiceItem(
            id: 'depilacion_laser',
            subcategoryId: 'depilacion',
            nameEs: 'Láser',
            serviceType: 'depilacion_laser',
          ),
          ServiceItem(
            id: 'depilacion_hilo',
            subcategoryId: 'depilacion',
            nameEs: 'Hilo',
            serviceType: 'depilacion_hilo',
          ),
          ServiceItem(
            id: 'depilacion_sugaring',
            subcategoryId: 'depilacion',
            nameEs: 'Sugaring',
            serviceType: 'depilacion_sugaring',
          ),
        ],
      ),
      ServiceSubcategory(
        id: 'tratamiento_corporal',
        categoryId: 'body_spa',
        nameEs: 'Tratamiento Corporal',
        items: [
          ServiceItem(
            id: 'corporal_exfoliacion',
            subcategoryId: 'tratamiento_corporal',
            nameEs: 'Exfoliación',
            serviceType: 'exfoliacion_corporal',
          ),
          ServiceItem(
            id: 'corporal_envolvimiento',
            subcategoryId: 'tratamiento_corporal',
            nameEs: 'Envolvimiento',
            serviceType: 'envolvimiento_corporal',
          ),
          ServiceItem(
            id: 'corporal_radiofrecuencia',
            subcategoryId: 'tratamiento_corporal',
            nameEs: 'Radiofrecuencia',
            serviceType: 'radiofrecuencia_corporal',
          ),
          ServiceItem(
            id: 'corporal_cavitacion',
            subcategoryId: 'tratamiento_corporal',
            nameEs: 'Cavitación',
            serviceType: 'cavitacion',
          ),
          ServiceItem(
            id: 'corporal_mesoterapia',
            subcategoryId: 'tratamiento_corporal',
            nameEs: 'Mesoterapia',
            serviceType: 'mesoterapia',
          ),
        ],
      ),
      ServiceSubcategory(
        id: 'bronceado',
        categoryId: 'body_spa',
        nameEs: 'Bronceado',
        items: [
          ServiceItem(
            id: 'bronceado_spray',
            subcategoryId: 'bronceado',
            nameEs: 'Spray',
            serviceType: 'spray_tan',
          ),
          ServiceItem(
            id: 'bronceado_cama',
            subcategoryId: 'bronceado',
            nameEs: 'Cama',
            serviceType: 'cama_bronceado',
          ),
        ],
      ),
    ],
  ),

  // 🧴 Cuidado Especializado
  ServiceCategory(
    id: 'specialized',
    nameEs: 'Cuidado Especializado',
    icon: '🧴',
    color: Color(0xFFFFA726),
    subcategories: [
      ServiceSubcategory(
        id: 'micropigmentacion_labios',
        categoryId: 'specialized',
        nameEs: 'Micropigmentación Labios',
        items: [
          ServiceItem(id: 'micropigmentacion_labios_item', subcategoryId: 'micropigmentacion_labios', nameEs: 'Micropigmentación Labios', serviceType: 'micropigmentacion_labios'),
        ],
      ),
      ServiceSubcategory(
        id: 'remocion_tatuajes',
        categoryId: 'specialized',
        nameEs: 'Remoción Tatuajes',
        items: [
          ServiceItem(id: 'remocion_tatuajes_item', subcategoryId: 'remocion_tatuajes', nameEs: 'Remoción de Tatuajes', serviceType: 'remocion_tatuajes'),
        ],
      ),
      ServiceSubcategory(
        id: 'blanqueamiento_dental',
        categoryId: 'specialized',
        nameEs: 'Blanqueamiento Dental',
        items: [
          ServiceItem(id: 'blanqueamiento_dental_item', subcategoryId: 'blanqueamiento_dental', nameEs: 'Blanqueamiento Dental', serviceType: 'blanqueamiento_dental'),
        ],
      ),
      ServiceSubcategory(
        id: 'consulta_virtual',
        categoryId: 'specialized',
        nameEs: 'Consulta Virtual',
        items: [
          ServiceItem(id: 'consulta_virtual_item', subcategoryId: 'consulta_virtual', nameEs: 'Consulta Virtual', serviceType: 'consulta_virtual'),
        ],
      ),
    ],
  ),

  // 💈 Barbería
  ServiceCategory(
    id: 'barberia',
    nameEs: 'Barbería',
    icon: '💈',
    color: Color(0xFF37474F),
    subcategories: [
      ServiceSubcategory(
        id: 'barberia_corte_hombre',
        categoryId: 'barberia',
        nameEs: 'Corte Hombre',
        items: [
          ServiceItem(id: 'barberia_corte_clasico', subcategoryId: 'barberia_corte_hombre', nameEs: 'Clásico', serviceType: 'barberia_corte_hombre'),
          ServiceItem(id: 'barberia_corte_moderno', subcategoryId: 'barberia_corte_hombre', nameEs: 'Moderno', serviceType: 'barberia_corte_moderno'),
        ],
      ),
      ServiceSubcategory(
        id: 'barberia_corte_barba',
        categoryId: 'barberia',
        nameEs: 'Corte + Barba',
        items: [
          ServiceItem(
            id: 'barberia_corte_barba_clasico',
            subcategoryId: 'barberia_corte_barba',
            nameEs: 'Clásico',
            serviceType: 'barberia_corte_barba',
          ),
        ],
      ),
      ServiceSubcategory(
        id: 'barberia_afeitado',
        categoryId: 'barberia',
        nameEs: 'Afeitado Clásico',
        items: [
          ServiceItem(
            id: 'barberia_afeitado_clasico',
            subcategoryId: 'barberia_afeitado',
            nameEs: 'Afeitado Clásico',
            serviceType: 'barberia_afeitado_clasico',
          ),
        ],
      ),
      ServiceSubcategory(
        id: 'barberia_diseno',
        categoryId: 'barberia',
        nameEs: 'Diseño Barba',
        items: [
          ServiceItem(
            id: 'barberia_diseno_barba',
            subcategoryId: 'barberia_diseno',
            nameEs: 'Diseño Barba',
            serviceType: 'barberia_diseno_barba',
          ),
        ],
      ),
      ServiceSubcategory(
        id: 'barberia_tratamiento',
        categoryId: 'barberia',
        nameEs: 'Tratamiento Barba',
        items: [
          ServiceItem(
            id: 'barberia_tratamiento_barba',
            subcategoryId: 'barberia_tratamiento',
            nameEs: 'Tratamiento Barba',
            serviceType: 'barberia_tratamiento_barba',
          ),
        ],
      ),
      ServiceSubcategory(
        id: 'barberia_fade',
        categoryId: 'barberia',
        nameEs: 'Fade/Degradado',
        items: [
          ServiceItem(id: 'barberia_fade_item', subcategoryId: 'barberia_fade', nameEs: 'Fade / Degradado', serviceType: 'barberia_fade'),
        ],
      ),
    ],
  ),
];
