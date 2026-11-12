#define _GNU_SOURCE
#include <dlfcn.h>
#include <stddef.h>

typedef void (*set_fn)(void *, void *);
typedef void (*pack_fn)(void *, void *);
typedef void (*unparent_fn)(void *);
typedef void (*remove_fn)(void *, void *);
typedef void *(*label_new_fn)(const char *);
typedef void (*label_set_text_fn)(void *, const char *);
typedef void (*label_set_xalign_fn)(void *, float);
typedef void (*widget_show_fn)(void *);
typedef void (*object_set_data_fn)(void *, const char *, void *);
typedef void *(*object_get_data_fn)(void *, const char *);

static void *next_symbol(const char *name) { return dlsym(RTLD_NEXT, name); }

static void detach(void *bar, void *widget) {
  unparent_fn unparent = (unparent_fn)next_symbol("gtk_widget_unparent");
  if (unparent) { unparent(widget); return; }
  remove_fn remove = (remove_fn)next_symbol("gtk_container_remove");
  if (remove) remove(bar, widget);
}

static void move_to_start(void *bar, void *widget, const char *pack) {
  if (!bar || !widget) return;
  detach(bar, widget);
  pack_fn fn = (pack_fn)next_symbol(pack);
  if (fn) fn(bar, widget);
}

static void title_label(void *bar, const char *title, const char *pack) {
  object_get_data_fn get_data = (object_get_data_fn)next_symbol("g_object_get_data");
  object_set_data_fn set_data = (object_set_data_fn)next_symbol("g_object_set_data");
  label_new_fn label_new = (label_new_fn)next_symbol("gtk_label_new");
  label_set_text_fn set_text = (label_set_text_fn)next_symbol("gtk_label_set_text");
  label_set_xalign_fn set_xalign = (label_set_xalign_fn)next_symbol("gtk_label_set_xalign");
  widget_show_fn show = (widget_show_fn)next_symbol("gtk_widget_show");
  if (!bar || !get_data || !set_data || !label_new || !set_text) return;
  void *label = get_data(bar, "windows-title-left");
  if (!label) {
    label = label_new(title ? title : "");
    if (!label) return;
    if (set_xalign) set_xalign(label, 0.0f);
    set_data(bar, "windows-title-left", label);
    pack_fn pack_fn_ptr = (pack_fn)next_symbol(pack);
    if (pack_fn_ptr) pack_fn_ptr(bar, label);
  } else {
    set_text(label, title ? title : "");
  }
  if (show) show(label);
}

#define WRAP_SETTER(symbol, pack) \
  void symbol(void *bar, void *widget) { \
    set_fn real = (set_fn)next_symbol(#symbol); \
    if (real) real(bar, widget); \
    move_to_start(bar, widget, pack); \
  }

#define WRAP_TITLE(symbol, clear_symbol, pack) \
  void symbol(void *bar, const char *title) { \
    set_fn clear = (set_fn)next_symbol(clear_symbol); \
    if (clear) clear(bar, ""); \
    title_label(bar, title, pack); \
  }

WRAP_SETTER(gtk_header_bar_set_title_widget, "gtk_header_bar_pack_start")
WRAP_SETTER(gtk_header_bar_set_custom_title, "gtk_header_bar_pack_start")
WRAP_SETTER(adw_header_bar_set_title_widget, "adw_header_bar_pack_start")
WRAP_SETTER(hdy_header_bar_set_custom_title, "hdy_header_bar_pack_start")
WRAP_TITLE(gtk_header_bar_set_title, "gtk_header_bar_set_title", "gtk_header_bar_pack_start")
WRAP_TITLE(hdy_header_bar_set_title, "hdy_header_bar_set_title", "hdy_header_bar_pack_start")
